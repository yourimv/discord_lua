local spawn = require('coro-spawn')
local parse = require('url').parse
local isActive = false
local songURLQueue = {}
local streamQueue = {}

local function getYoutubedl(argsTable, url)
    local child = spawn('youtube-dl', {
        args = {'-g', url},
        stdio = { nil, true, 2 }
    })
    return child
end

local function addSongToStreamQueue (url, message)
    if url == nil then return end
    print(url)
    local child = spawn('youtube-dl', {
        args = {'-g', url},
        stdio = { nil, true, nil }
    })
    if not child then
        isActive = false
        return message.channel:send('Error sourcing youtube-dl')
    end
    local msg = message.channel:send('Fetching '..url..'... :fishing_pole_and_fish:')
    local stream
    for chunk in child.stdout.read do
        local urls = chunk:split('\n')
        for _, yturl in pairs(urls) do
            local mime = parse(yturl, true).query.mime
            if mime and mime:find('audio') == 1 then
                stream = yturl
            end
        end
    end
    table.insert(streamQueue, stream)
    msg:setContent('Now playing '..url..' :ok_hand:')
end

local function getYoutubeVideoInfo(url)
    local url = url
    if string.sub(url,1,#"https:") ~= "https:" then
            url = "ytsearch:" .. url
    end
    local res = spawn("youtube-dl",{
            args = {"-j","--rm-cache-dir","--skip-download",url},
            stdio = {nil, true, nil}
    })
    local information = {}
    local json_string=""
    for i in res.stdout.read do
            json_string = json_string .. i
    end
    local table_ = json.decode(json_string)
    for _, formats in pairs(table_.formats) do
            if formats["protocol"] == "https" and formats["container"] == "m4a_dash" then
                    information["stream_url"] = formats["url"]
                    break
            end
    end
    information["thumbnail"] = table_["thumbnail"]
    information["fulltitle"] = table_["fulltitle"]
    information["view_count"] = table_["view_count"]
    information["duration"] = table_["duration"]
    information["channel_url"] = table_["channel_url"]
    information["uploader"] = table_["uploader"]
    information["id"] = table_["id"]
    print(information["duration"])
    return information
end

local play
play = function(vc, connection, message)
    if next(streamQueue) == nil then
        connection:close()
        isActive = false
        return
    end
    local conn = vc:join()
    conn:playFFmpeg(table.remove(streamQueue,1))
    addSongToStreamQueue(table.remove(songURLQueue,1), message)
    play(vc, conn)
end

return {
	name = 'play',
	description = 'plays a song from a youtube url',
    command = function(args, message, client, rest)
        local requester = message.guild:getMember(message.author)
        local vc = requester.voiceChannel
        if vc == nil then
            message.channel:send('You must be connected to a voice channel in order to use this command')
            return
        end
        if string.match(args[1], "v=(...........)") == nil then
            message.channel:send {
                content = 'Youtube URL not valid',
                reference = {
                    message = message,
                    mention = false,
                }
            }
            return
        end
        if not isActive then
            isActive = true
            addSongToStreamQueue(args[1], message)
            play(vc, nil, message)
        else
            table.insert(songURLQueue, args[1])
            message.channel:send {
                content = 'Added '..args[1]..' to the song queue :pencil:',
                reference = {
                    message = message,
                    mention = false,
                }
            }
        end
	end
};