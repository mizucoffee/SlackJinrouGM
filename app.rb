require 'slack'
require './models.rb'
require './jinrou.rb'

SLACK_TOKEN = ENV['JINROU_SLACK_TOKEN'].freeze
JINROU_ROOM = ENV['JINROU_SLACK_ROOM'].freeze

Slack.configure { |config| config.token = SLACK_TOKEN }
client = Slack.realtime

def postSlack(channel, text)
    params = {token: SLACK_TOKEN,channel: channel,text: text,}
    Slack.chat_postMessage params
end

def getUserName(id)
    params = {token: SLACK_TOKEN,user: id,}
    user = Slack.users_info params
    user['user']['name']
end

jinrou = Jinrou.new

client.on :hello do
    puts 'Successfully connected.'
end

client.on :message do |data|
    if data['subtype'] == nil

        channel  = data['channel']
        userid   = data['user']
        text     = data['text']
        username = getUserName(userid)

        if text == '人狼終了' && jinrou.isSlackMaster(userid)
            jinrou = Jinrou.new
            postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
人狼を終了しました！お疲れ様でした！")
        end

        jinrou.checkText(text,userid,username,channel)

        if jinrou.checkFinish
            jinrou = Jinrou.new
            postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
人狼を終了しました！お疲れ様でした！")
        end
    end
end

client.start
