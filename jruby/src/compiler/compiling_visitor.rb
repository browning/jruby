#
# Copyright (C) 2002 Anders Bengtsson <ndrsbngtssn@yahoo.se>
#
# JRuby - http://jruby.sourceforge.net
#
# This file is part of JRuby
#
# JRuby is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# JRuby is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with JRuby; if not, write to
# the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA  02111-1307 USA

require 'java'
require 'bytecode.rb'

module JRuby
  module AST
    include_package 'org.jruby.ast.visitor'
    include_package 'org.jruby.ast'
  end
end

module JRuby
  module Compiler

    require 'bcel.rb'

    class BytecodeSequence
      include Enumerable

      def initialize
        @bytecodes = []
      end

      def <<(bytecode)
        @bytecodes << bytecode
      end

      def each
        @bytecodes.each {|b| yield(b) }
      end

      def [](index)
        @bytecodes[index]
      end

      def jvm_bytecode
        list = BCEL::InstructionList.new
        @bytecodes.each {|b| b.emit_jvm_bytecode(list) }
        code = list.getByteCode
        result = []
        for i in 0...code.length
          if code[i] >= 0
            result << code[i]
          else
            result << code[i] + 256
          end
        end
        result
      end
    end

    module CompilingVisitor
      include JRuby::Compiler::Bytecode

      def method_missing(name)
        puts "Missing implementation for #{name}"
      end

      def compile(tree)
        @bytecodes = BytecodeSequence.new
        emit_bytecodes(tree)
        @bytecodes
      end

      def emit_bytecodes(node)
        node.accept(self)
      end

      def visitNewlineNode(node)
        emit_bytecodes(node.getNextNode)
      end

      def visitLocalAsgnNode(node)
        emit_bytecodes(node.getValueNode)
        @bytecodes << AssignLocal.new(node.getCount)
      end

      def visitFixnumNode(node)
        @bytecodes << PushFixnum.new(node.getValue)
      end

      def visitFCallNode(node)
        @bytecodes << PushSelf.new
        iter = node.getArgsNode.iterator
        while iter.hasNext
          emit_bytecodes(iter.next)
        end
        @bytecodes << Call.new(node.getName,
                               node.getArgsNode.size,
                               :functional)
      end

      def visitStrNode(node)
        @bytecodes << PushString.new(node.getValue)
      end

      def visitSelfNode(node)
        @bytecodes << PushSelf.new
      end
    end

    # Since we can't subclass Java interfaces properly we have
    # to do this magic to get CompilingVisitor to behave like
    # a class.
    def CompilingVisitor.new
      nodeVisitor = JRuby::AST::NodeVisitor.new
      class << nodeVisitor
        include CompilingVisitor
      end
      nodeVisitor
    end
  end
end
