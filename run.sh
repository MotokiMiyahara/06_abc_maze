#!/bin/sh
# vim:set fileencoding=utf-8 ts=2 sw=2 sts=2 et:
for N in `seq 1 7`
do
  COMMAND="ruby maze_info.rb $@ abc_maze/case${N}.in.txt"
  #echo "$COMMAND"
  $COMMAND
done
