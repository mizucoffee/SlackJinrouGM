class User
    attr_accessor :id, :name, :channel, :job, :status, :alive, :touhyou_count
    def initialize
        @id                = ""   # ユーザーの固定ID
        @name              = ""   # ユーザーの可変ID
        @channel           = ""   # ユーザーのDMチャンネル
        @job               = ""   # ユーザーの職業
        @status            = true   # そのターンに行動をしたか
        @alive             = true # ユーザーの生存/死亡
        @touhyou_count     = 0
    end
end

class Player
    attr_accessor :werewolf, :villager, :fortune, :player_count
    def initialize
        @werewolf          = 0 # 人狼の人数
        @villager          = 0 # 村人の人数
        @fortune           = 1 # 占師の人数

        @player_count      = 0 # プレイヤーの人数
        #@alive_count       = 0 # 生存プレイヤーの人数 （これはaliveから割り出せるからメソッド化したほうがミスが減る
    end
end

class Game
    attr_accessor :game_count, :game_count, :day, :touhyou_count, :time, :touhyou, :slack_master, :authcode, :killed_user
    def initialize
        @game_count        = 0 # カウント
        @day         = 0 # 経過日数
        @time              = 0 # 時間
        @touhyou           = false # 投票モード
        @touhyou_count     = 0 # 投票件数

        @slack_master = ''
        @authcode = ''
        @killed_user = ""
    end
end
