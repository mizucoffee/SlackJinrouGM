class Jinrou

    SLACK_TOKEN = ENV['JINROU_SLACK_TOKEN'].freeze
    JINROU_ROOM = ENV['JINROU_SLACK_ROOM'].freeze

    delay = 2 # 何秒間を開けるか

    def postSlack(channel, text)
        params = {token: SLACK_TOKEN,channel: channel,text: text,}
        Slack.chat_postMessage params
    end

    def getUserName(id)
        params = {token: SLACK_TOKEN,user: id,}
        user = Slack.users_info params
        user['user']['name']
    end

    def isSlackMaster(userid)
        @game.slack_master == userid
    end

    def initialize()
        @game = Game.new
        @player = Player.new
        @users = []
    end

    def checkText(text,userid,username,channel)

        case @game.game_count
        when 0
            startGame(text,userid,username,channel) if text == '人狼開始' && channel == JINROU_ROOM
        when 1
            startAuth(text,userid,username,channel) if /^\d+$/ =~ text && isSlackMaster(userid) && channel == JINROU_ROOM
        when 2
            auth(text,userid,username,channel)      if text == @game.authcode && /^D/ =~ channel
        when 3
            startWait(text,userid,username,channel) if /^\d+$/ =~ text && isSlackMaster(userid) && channel == JINROU_ROOM
        when 4
            startPlay(text,userid,username,channel) if text == '準備完了' && isSlackMaster(userid) && channel == JINROU_ROOM
        when 5
            user = @users[@users.index {|user| user.id == userid}]

            case @game.time
            when 0
            when 1
                if @game.touhyou
                    unless user.status
                        if /^D/ =~ channel && /^<@U.*>:$/ =~ text
                            voteUser($&,userid,username,channel)
                        end
                    else
                        postSlack(channel, "既に投票しています。みなさんの投票が終了するまでお待ち下さい。")
                    end
                end
                # divineUser(text,userid,username,channel) if /^D/ =~ channel && /^<@U.*>:$/ =~ text
            when 2
                unless user.status
                    case user.job
                    when "werewolf"
                        if /^D/ =~ channel && /^<@U.*>:$/ =~ text
                            killUser($&,userid,username,channel)
                        end
                    when "fortune"
                        if /^D/ =~ channel && /^<@U.*>:$/ =~ text
                            divineUser($&,userid,username,channel)
                        end
                    when "villager"
                    end
                else
                    #postSlack(channel, "既に行動しています。夜が明けるまでお待ち下さい。")
                end
            end
        end
    end

    def startGame(text,userid,username,channel)
        @game.game_count   = 1
        @game.slack_master = userid

        postSlack(JINROU_ROOM, "人狼を開始します！まずはプレイ人数を教えて下さい！（半角数字のみで答えてください）\nまた、途中で終了したいときはSMが「人狼終了」と言ってください。")
    end

    def startAuth(text,userid,username,channel)
        @game.game_count     = 2
        @game.authcode = ("あ".."ん").to_a.sample(5).join
        @player.player_count = text.to_i

        postSlack(JINROU_ROOM, "#{@player.player_count}人ですね！それでは、参加する人は @jinrou_gm にdmで「#{@game.authcode}」と送信してください！\n全員が認証するまでしばらくお待ち下さい！\n----------------------------------------------------------------------------")
    end

    def auth(text,userid,username,channel)

        if @users.count { |user| user.id == userid } == 0
            user = User.new
            user.id = userid
            user.name = username
            user.channel = channel
            @users << user

            postSlack(channel, "人狼のプレイヤーとして認証しました！")
            postSlack(JINROU_ROOM, "#{username}さんの認証が完了しました！")

            if @player.player_count == @users.length
                @game.game_count = 3
                postSlack(JINROU_ROOM, "----------------------------------------------------------------------------\n続きまして人狼と村人の準備をします。この質問はSMが答えてください。人狼の人数は何人にしますか？（人狼は村人より少ない必要があります）")
            end
        else
            postSlack(channel, "既に人狼のプレイヤーとして認証されています！")
        end
    end

    def startWait(text,userid,username,channel)
        @player.werewolf = text.to_i
        @player.villager = @player.player_count - @player.werewolf - @player.fortune

        if @player.werewolf < @player.villager + @player.fortune
            @game.game_count = 4

            postSlack(JINROU_ROOM, "#{@player.werewolf}人ですね！\n----------------------------------------------------------------------------\nそれでは、人狼の準備が完了しました。皆さんにDMで役職をお知らせします。")

            jobs = []
            i = 0
            for num in 1..@player.werewolf
                jobs[i] = "werewolf"
                i += 1
            end
            for num in 1..@player.fortune
                jobs[i] = "fortune"
                i += 1
            end
            for num in 1..@player.villager
                jobs[i] = "villager"
                i += 1
            end
            jobs.shuffle!
            for num in 0..@player.player_count - 1
                @users[num].job = jobs[num]
            end

            @users.each { |user|
                case user.job
                when "werewolf"
                    postSlack(user.channel, "あなたは *人狼* です。")
                when "fortune"
                    postSlack(user.channel, "あなたは *占師* です。")
                when "villager"
                    postSlack(user.channel, "あなたは *村人* です。")
                end
            }

            postSlack(JINROU_ROOM, "準備が出来ましたら、SMさんが「準備完了」と言ってください。")
        else
            postSlack(JINROU_ROOM, "村人と同じ、または村人より人狼の人数が上回っています。もう一度設定してください。\n人狼の人数は何人にしますか？（人狼は村人より少ない必要があります）")
        end
    end

    def startPlay(text,userid,username,channel)
        postSlack(JINROU_ROOM, "それでは人狼を開始します。")

        @game.time = 1
        @game.day = 1
        @game.game_count = 5

        postSlack(JINROU_ROOM,"----------------------------------------------------------------------------
#{@game.day}日目/昼
皆さんの中に、人狼が紛れ込んでいます。人狼は毎晩、村人の中から１人づつ殺していきます。
村人は、すべての人狼を処刑することができれば勝利です。
人狼は、村人と人間の人数が同じになれば勝利です。")

        @game.time = 2
        postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
#{@game.day}日目/夜
最初の夜が来ました。
それでは皆さん、おやすみなさい。")

        @users.each { |user|
            if user.job == "fortune"
                postSlack(user.channel, "占師さん。おはようございます。
占師は、人を一人占う事ができ、人狼かどうかを判別することが出来ます。
占う人を指定してください。（形式は半角で@と打ち、候補の中から選んでください。手入力する際は\"@ユーザーID: \"となるように入力してください。")
                user.status = false
            end
        }
    end

    def divineUser(text,userid,username,channel)
        searchUser = text[2,text.index(">")-2]
        me   = @users[@users.index {|user| user.id == userid}]
        user = @users[@users.index {|user| user.id == searchUser}]

        unless userid == searchUser
            if user.alive
                if user.job == "werewolf"
                    postSlack(channel, "#{getUserName(searchUser)}さんは *人狼* です。")
                else
                    postSlack(channel, "#{getUserName(searchUser)}さんは *村人* です。")
                end
                me.status = true
            else
                postSlack(channel, "#{getUserName(searchUser)}さん既に死亡しています。")
            end
        else
            postSlack(channel, "自分を占うことは出来ません。")
        end

        f = true
        @users.each { |user1|
            if user1.alive
                f = false unless user1.status
            end
        }

        nextDay() if f
    end

    def killUser(text,userid,username,channel)
        searchUser = text[2,text.index(">")-2]
        me   = @users[@users.index {|user| user.id == userid}]
        user = @users[@users.index {|user| user.id == searchUser}]
        unless userid == searchUser
            if user.alive
                # user.alive = false
                @game.killed_user = getUserName(searchUser)
                postSlack(channel, "#{getUserName(searchUser)}さんを殺しました。")
                me.status = true
            else
                postSlack(channel, "#{getUserName(searchUser)}さんは既に死亡しています。")
            end
        else
            postSlack(channel, "自分を殺すことは出来ません。")
        end

        f = true
        @users.each { |user1|
            if user1.alive
                 f = false unless user1.status
            end
        }

        nextDay() if f
    end

    def nextDay()
        @game.day += 1
        @game.time = 0

        if @game.day == 2
            postSlack(JINROU_ROOM,"----------------------------------------------------------------------------
#{@game.day}日目/朝
皆さんおはようございます。
昨夜は何もありませんでしたが、今日からは人狼に村人が殺されていきます。")
        else
            user = @users[@users.index {|user| user.name == @game.killed_user}]
            user.alive = false
            postSlack(JINROU_ROOM,"----------------------------------------------------------------------------
#{@game.day}日目/朝
皆さんおはようございます。
昨夜は人狼に#{@game.killed_user}さんが殺されてしましました。")
        postSlack(user.channel, "あなたは死亡しました。これ以降、チャットには参加しないでください。")
        end

        return if checkFin
        @game.time = 1

        postSlack(JINROU_ROOM,"----------------------------------------------------------------------------
#{@game.day}日目/昼
昼になりましたので処刑会議の時間です。
皆さんで話し合って、処刑する人を決めてください。
会議時間は2分です。
----------------------------------------------------------------------------")
        sleep(10)

        postSlack(JINROU_ROOM,"----------------------------------------------------------------------------
皆さん、結果はまとまりましたでしょうか。それでは投票を取りたいと思います。
DMで@jinrou_gmに対してユーザーを投票してください。
（形式は半角で@と打ち、候補の中から選んでください。手入力する際は\"@ユーザーID:\"となるように入力してください。")
        @game.touhyou = true
        @game.touhyou_count = 0
        @users.each { |user|
            user.status = false
        }

    end

    def voteUser(text,userid,username,channel)
        searchUser = text[2,text.index(">")-2]
        user = @users[@users.index {|user| user.id == searchUser}]
        me   = @users[@users.index {|user| user.id == userid}]

        if me.alive
            if user.alive
                unless userid == searchUser
                    me.status = true
                    user.touhyou_count += 1
                    @game.touhyou_count += 1
                    postSlack(channel, "#{getUserName(searchUser)}さんに投票しました。")
                else
                    postSlack(channel, "自分に投票することは出来ません。")
                end
            else
                postSlack(channel, "#{getUserName(searchUser)}さんは既に死亡しています。")
            end
        else
            postSlack(channel, "自分は既に死亡しているので投票権はありません。")
        end

        if @users.count {|user| user.alive} == @game.touhyou_count

            max = @users.max { |a,b|a.touhyou_count <=> b.touhyou_count}.touhyou_count

            if @users.count{|user|user.touhyou_count == max} == 1
                syokei = @users[@users.index{|user|user.touhyou_count == max}]
                postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
全員の投票が終わりました。投票の結果は#{syokei.name}さんでした。
よって、#{syokei.name}さんは処刑されます。")
                postSlack(syokei.channel, "あなたは死亡しました。これ以降、チャットには参加しないでください。")
                @touhyou = false
                @users.each { |user|
                    user.touhyou_count = 0
                }
                @touhyou_count = 0
                syokei.alive = false

                return if checkFin

                @game.time = 2
                postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
#{@game.day}日目/夜
夜になりました。
それでは皆さん、おやすみなさい。")

                @users.each { |user|
                    if user.alive
                        case user.job
                        when "fortune"
                            postSlack(user.channel, "占師さん。おはようございます。
占師は、人を一人占う事ができ、人狼かどうかを判別することが出来ます。
占う人を指定してください。（形式は半角で@と打ち、候補の中から選んでください。手入力する際は\"@ユーザーID: \"となるように入力してください。")
                            user.status = false
                        when "werewolf"
                            postSlack(user.channel, "人狼さん。おはようございます。
人狼は、人を一人を食い殺すことが出来ます。
殺す人を指定してください。（形式は半角で@と打ち、候補の中から選んでください。手入力する際は\"@ユーザーID: \"となるように入力してください。")
                            user.status = false
                        end
                    end
                }
            else
                postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
同一票がありましたので、もう一度投票していただきます。
DMで@jinrou_gmに対してユーザーを投票してください。
（形式は半角で@と打ち、候補の中から選んでください。手入力する際は\"@ユーザーID:\"となるように入力してください。")
                @touhyou = true
                @touhyou_count = 0
                @users.each { |user|
                    user.status = false
                    user.touhyou_count = 0
                }
            end
        end
    end

    def checkFin
        if @game.game_count == 5
            return true if @users.count {|user| user.job == "werewolf" && user.alive } == 0
            return true if @users.count {|user| user.job != "werewolf" && user.alive } <= @users.count {|user| user.job == "werewolf" && user.alive }
        end
        return false
    end

    def checkFinish
        if @game.game_count == 5
            if @users.count {|user| user.job == "werewolf" && user.alive } == 0
                postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
村人の皆さん。おめでとうございます。
全ての人狼がいなくなりましたので、村人の勝利です。")
                return true
            end
            if @users.count {|user| user.job != "werewolf" && user.alive } <= @users.count {|user| user.job == "werewolf" && user.alive }
                postSlack(JINROU_ROOM, "----------------------------------------------------------------------------
人狼の皆さん。おめでとうございます。
村人が人狼と同数、またはそれより少なくなりましたので、人狼の勝利です。")
                return true
            end
        end
        return false
    end
end
