module("luci.controller.radu", package.seeall)

function index()
    entry({"admin", "tools", "radu"}, call("action_page"), _("Custom Background"), 99)
end

function action_page()
    local http = require "luci.http"
    local fs   = require "nixio.fs"
    local json = require "luci.jsonc"

    local target_dir = "/www/luci-static/alpha/background/"
    local dashboard_file = target_dir .. "dashboard.png"
    local login_file = target_dir .. "login.png"

    local message = nil
    local success = false

    -- === UPLOAD LOCAL FILE ===
    if http.formvalue("upload") then
        local tmp_file = "/tmp/radu_upload"
        local out = io.open(tmp_file, "wb")

        if out then
            http.setfilehandler(function(_, chunk, eof)
                if chunk then out:write(chunk) end
                if eof then out:close() end
            end)

            http.formvalue("file") -- triggers read

            if fs.stat(tmp_file) then
                fs.copy(tmp_file, dashboard_file)
                fs.copy(tmp_file, login_file)
                fs.remove(tmp_file)
                message = "✅ Local file updated!"
                success = true
            else
                message = "❌ Upload failed, no file received"
            end
        else
            message = "❌ Cannot write to /tmp"
        end
    end

    -- === APPLY IMAGE FROM URL ===
    if http.formvalue("apply_url") then
        local url = http.formvalue("image_url")

        if url and #url > 5 then
            os.execute(string.format('curl -s -L -A "Mozilla/5.0" -o "%s" "%s"', dashboard_file, url))
            os.execute(string.format('cp "%s" "%s"', dashboard_file, login_file))

            if fs.stat(dashboard_file) then
                message = "🌍 Image downloaded from URL!"
                success = true
            else
                message = "❌ Failed to download image"
            end
        else
            message = "⚠️ URL required"
        end
    end

    -- === RANDOM WALLPAPER USING WALLHAVEN API ===
    if http.formvalue("randomize") then
        local api_tmp = "/tmp/radu_api.json"
        os.execute('curl -s -A "Mozilla" "https://wallhaven.cc/api/v1/search?sorting=random&purity=100&categories=110" -o ' .. api_tmp)

        local data = fs.readfile(api_tmp)
        if data then
            local parsed = json.parse(data)
            if parsed and parsed.data and parsed.data[1] and parsed.data[1].path then
                local image_url = parsed.data[1].path

                os.execute(string.format('curl -s -L -A "Mozilla/5.0" -o "%s" "%s"', dashboard_file, image_url))
                os.execute(string.format('cp "%s" "%s"', dashboard_file, login_file))

                if fs.stat(dashboard_file) then
                    message = "🎉 Random wallpaper applied!"
                    success = true
                else
                    message = "❌ Failed fetching random wallpaper"
                end
            else
                message = "❌ API returned no image"
            end
        else
            message = "❌ Failed contacting API"
        end
    end

    luci.template.render("radu", {success = success, message = message})
end
