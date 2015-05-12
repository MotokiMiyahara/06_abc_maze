#!/usr/bin/env ruby
# vim:set fileencoding=utf-8 ts=2 sw=2 sts=2 et:
#
# 概要:
#   ./maze_info.rb [OPTION] {filename}
#     {filename}から迷路データをデータを読み込み、ゴールに到達可能か出力します
#
# 使用例:
#   ./maze_info.rb case1.in.txt
#
#
# OPTIONS
#     -d, --debug
#       デバッグ情報を出力します(ゴールまでの経路など)
#
# 

# アルゴリズムについて
#   1.部屋の種類をシンボルの2次元配列として保持します[@type_2d]
#     (このとき、配列の範囲チェックを省略するため、周囲を壁データ[nil]で囲んでいます)
# 
#   2.部屋が調査済みかを表す情報を真偽値の2次元配列として保持します[@is_marked_2d]
#   3.スタート地点の部屋を始点として下記の調査を行います
#     a.この部屋を調査済みとして登録
#     b.この部屋がゴール地点なら,この迷路はゴール可能
#     c.未調査かつ移動可能な部屋[次部屋]のそれぞれを始点として,ゴール可能か調査する
#       c-1.ゴールに到達可能な次部屋が1つでも存在すれば、この部屋からゴールに到達可能
#       c-2.存在しなければ、この部屋からはゴールに到達不可能

# 注意点
#   このプログラムはUTF-8で記述したものをShift-JISに変換しています。(解答フォーマットに合わせるため)
#   プログラムを実行する前にUTF-8に再変換して下さい。

# ※主要なクラス(Maze)が1下の方に埋もれているのは,1ファイル制限のためなのでご了承ください

require 'pp'
require 'optparse'

module Abc
   
  # 部屋の場所を表す
  # Value Object
  class Point
    attr_reader :x, :y
    def initialize(x, y)
      @x = x
      @y = y
    end

    # 隣接する場所を返す
    # @return [Enumerable<Point>]
    def neighbors
      return [right, left, up, down]
    end
    
    # @return [Point]
    def right
      return move_by( 1,  0)
    end

    # @return [Point]
    def left
      return move_by(-1,  0)
    end

    # @return [Point]
    def up
      return move_by( 0, -1)
    end

    # @return [Point]
    def down
      return move_by( 0,  1)
    end

    # @return [Point]
    def move_by(x_dirction, y_direction)
      return self.class.new(@x + x_dirction, @y + y_direction)
    end

    def ==(other)
      self.class == other.class && @x == other.x && @y == other.y
    end

    def hash
      return @x.hash ^ @y.hash
    end
    alias eql? ==

    def to_s
      return format('%d@%d', @x, @y)
    end

    def inspect
      return format('#<%d@%d>', @x, @y)
    end
  end

  # 2次元配列を操作する関数をまとめたもの
  module Array2dUtil
    module_function
     
    # 2次元配列を特定の要素で囲んだものを返します
    # 要素は同一のオブジェクトが参照されます
    # @param [Array<Array<<Object>>] 囲まれる2次元配列(矩形であること)
    # @param [Object] padding 囲む要素(不変のValueObjectであること)
    # @example
    #   array = [[:a, :b], [:c, :c]]
    #   surround(array, padding: nil)
    #     =>
    #         [[nil, nil, nil, nil],
    #          [nil, :a, :b, nil],
    #          [nil, :c, :c, nil],
    #          [nil, nil, nil, nil]]
    #
    def surround(array_2d, padding:)
      inner_type_table = array_2d.dup
      inner_width = inner_type_table[0].size

      # inner_type_table の外周をpaddingで囲んだ2次元配列を生成
      outer_width = inner_width + 2
      outer_type_table = [Array.new(outer_width, padding)] +
                         inner_type_table.map{|line| [padding] + line + [padding]} +
                         [Array.new(outer_width, padding)] 

     return outer_type_table
    end

    # array_2dとサイズが等しく, 要素がvalである2次元配列を返します
    # 要素は同一のオブジェクトが参照されます
    # @param [Array<Array<<Object>>] 元の2次元配列(矩形であること)
    # @param [Object] val 2次元配列の要素(不変のValueObjectであること)
    #   array = [[:a, :b], [:c, :c]]
    #   same_size_array_2d(array, val: false)
    #     =>
    #        [[false, false], [false, false]]
    #
    def same_size_array_2d(array_2d, val:)
      width = array_2d[0].size
      height = array_2d.size
      return Array.new(height){Array.new(width, val)}
    end

  end

  class Maze
    include Array2dUtil

    class << self
      def create_from_file(file)
        open(file, 'r:UTF-8') do |f|
          lines = f.readlines
          type_2d = lines.map{|line| line.chomp.chars.map(&:upcase).map(&:to_sym)}
          return new(type_2d)
        end
      end
    end

    # @param[Array<Array<Symbol>>] type_2d
    def initialize(inner_type_2d)
      @type_2d = surround(inner_type_2d, padding: nil)
      width = inner_type_2d[0].size
      height = inner_type_2d.size

      @start_pos = Point.new(0, 0)
      @goal_pos = Point.new(width - 1, height - 1)
    end


    # 迷路の情報を返します
    # @return[MazeReport]
    def make_report
      @is_marked_2d = same_size_array_2d(@type_2d, val: false)
      @route = []
      can_reach_goal = walk(@start_pos)

      report = MazeReport.new(can_reach_goal, @route)
      return report
    end

    private 
    # current_posからゴールまで辿りつけるときtrue
    # @memo
    #   このメソッドが下記の変数を更新することに注意してください
    #     @is_marked_2d
    #     @route
    def walk(current_pos)
      mark(current_pos)
      @route.push(current_pos)

      if current_pos == @goal_pos
        return true
      end

      if next_pos_list(current_pos).any?{|next_pos| walk(next_pos)}
        return true
      else
        @route.pop
        return false
      end
    end

    # 次の調査対象の部屋の位置を取得する
    # @param [Point] 現在の部屋の位置
    # @return [Array<Point>]
    def next_pos_list(point)
      return point.neighbors.select{|p|

        # 調査済みの部屋を除外
        next false if mark?(p)

        # 経路を[A -> B -> C -> ...] に限定する
        case type(point)
        when :A
          type(p) == :B
        when :B
          type(p) == :C
        when :C
          type(p) == :A
        else
          raise "unexpected type: :#{type(point)} (#{point})"
        end
      }
    end

    # 部屋の種類を取得する
    # @param [Point] 部屋の位置
    # @return [Symbol]
    def type(point)
      x, y = indexes_from_point(point)
      return @type_2d[y][x]
    end

    # 調査済みの部屋をマークする
    # @param [Point] 部屋の位置
    def mark(point)
      x, y = indexes_from_point(point)
      return @is_marked_2d[y][x] = true
    end

    # 部屋が調査済みのときtrue
    # @param [Point] 部屋の位置
    def mark?(point)
      x, y = indexes_from_point(point)
      return @is_marked_2d[y][x]
    end

    # 部屋の位置から内部表現用の配列添字を得る
    # @param [Point] 部屋の位置
    # @return [Integer, Integer]
    def indexes_from_point(inner_point)
      outer_point = inner_point.move_by(1, 1)
      return outer_point.x, outer_point.y
    end
  end

  # 迷路情報
  class MazeReport
    # スタート地点からゴール地点までの経路の1つ
    #   (経路が存在しないときは殻の配列を返す)
    # @return [Array<Point>]
    attr_reader :route

    def initialize(can_reach_goal, route)
      @can_reach_goal = can_reach_goal
      @route = route.dup.freeze
    end

    # 迷路がゴールできるときtrue
    # @return [Boolean]
    def can_reach_goal?
      return @can_reach_goal
    end
  end
end


# 標準入出力とのやりとりを定義
module Interaction
  extend Abc

  class << self
    public
    def main
      opts = parse_opts!(ARGV)
      file = ARGV[0]
      maze = Maze.create_from_file(file)
      report = maze.make_report

      if opts[:do_debug]
        show_debug_info(file, report)
      else
        show_answer(report)
      end
    end

    private
    def show_answer(report)
      puts report.can_reach_goal? ? 'possible' : 'impossible'
    end

    def show_debug_info(file, report)
      puts '-------------------------------------------------'
      puts "[#{file}]"
      pp report
    end
  
    # コマンドラインオプションを解析する
    # 引数argvは変更される
    # @return [Hash]
    def parse_opts!(argv)
      opts = {}
      parser = OptionParser.new
      parser.on('-d', '--debug', 'debug mode'){|v| opts[:do_debug] = v}
      parser.parse!(argv)
      return opts
    end

  end
end

if $0 == __FILE__
  Interaction::main
end

