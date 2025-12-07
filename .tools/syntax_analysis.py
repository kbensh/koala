#!/usr/bin/env python3

# Good points of reference:
# https://github.com/binpash/shasta/blob/main/shasta/ast_node.py
# https://github.com/binpash/Shseer/blob/8bb9e72f7fe1b4703fc963bfa5d5bd2837e80ab3/src/shseer/symb.py

import sys
from enum import StrEnum, auto
from dataclasses import dataclass
import operator
from collections import Counter
import sys
import tempfile
import os
import libdash
import functools as ft
from shasta.json_to_ast import to_ast_node
from shasta.ast_node import (
    AndNode,
    ArgChar,
    EArgChar,
    CArgChar,
    TArgChar,
    AArgChar, VArgChar, QArgChar, BArgChar,
    AstNode,
    CArgChar,
    CaseNode,
    CommandNode,
    DefunNode,
    DupRedirNode,
    FileRedirNode,
    ForNode,
    HeredocRedirNode,
    IfNode,
    NotNode,
    OrNode,
    PipeNode,
    RedirNode,
    SemiNode,
    SubshellNode,
    WhileNode,
    BackgroundNode,
    AssignNode,
)
from collections import namedtuple

sys.setrecursionlimit (9001)

# Node With Source
NodeWSource = namedtuple('NodeWSource', ['node', 'source_syntax', 'linum_before', 'linum'])

first_time = True

def parse_shell_script(path):
    global first_time
    path = str(path)
    
    try:
        raw_asts = libdash.parse(path, first_time)
        first_time = False
        return [NodeWSource(to_ast_node(raw_ast),
                            source,
                            linum_before,
                            linum)
                   for (raw_ast, source, linum_before, linum) in raw_asts]
        
    except UnicodeDecodeError:
        with open(path, 'rb') as f:
            raw_data = f.read()

        clean_content = raw_data.decode('utf-8', errors='ignore')
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as tmp:
            tmp.write(clean_content)
            tmp_path = tmp.name
            
        try:
            raw_asts = libdash.parse(tmp_path, first_time)
            first_time = False
            return [NodeWSource(to_ast_node(raw_ast),
                                source,
                                linum_before,
                                linum)
                       for (raw_ast, source, linum_before, linum) in raw_asts]
        except Exception as e:
            print(f"Failed to parse sanitized version of {path}: {e}", file=sys.stderr)
            return []
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    except Exception as e:
        print(f"Error processing {path}: {e}", file=sys.stderr)
        return []

class NodeVariant(StrEnum):
    """
    Components are listed exhaustively here for documentation purposes.
    So that we have the string names.

    It is likely that we want to add more variants for command names, so it makes sense
    to define a node kind for our purposes.
    """
    PIPELINE = auto() # command1 | command2
    BACKGROUND = auto() # command1 &
    SUBSHELL_COMMAND = auto() # (command)
#     SEMICOLON_COMMAND = auto() # command1; command2 # this is not useful
    AND_COMMAND = auto() # command1 && command2
    OR_COMMAND = auto() # command1 || command2
    NEGATE_COMMAND = auto() # !command1 
    WHILE_COMMAND = auto() # while cond; do command2; end 
    FOR_COMMAND = auto() # for cond; do command2; end 
    IF_COMMAND = auto() # for cond; then command2; fi
    CASE_COMMAND = auto() # case cond; then command2; fi
    FUNCTION_COMMAND = auto() # fname() { fdefinition }

    ASSIGNMENT = auto() # a=b

    REDIRECTION = auto() # command >> file.txt
    FILE_REDIRECTION = auto() # command >> file.txt
#     TRUNCATE_FILE_REDIRECTION = auto()
#     TRUNCATE_FORCE_FILE_REDIRECTION = auto() # >|
#     INPUT_FILE_REDIRECTION = auto() # <
#     READ_WRITE_FILE_REDIRECTION = auto() # <>
#     APPEND_FILE_REDIRECTION = auto() # >|

    DUP_REDIRECTION = auto() # >&
    HEREDOC_REDIRECTION = auto() # <<EOF

    HOME_TILDE_CONTROL = auto() # ~s
    VARIABLE_USE = auto() # $something
    DOLLAR_PAREN_SHELL_CONTROL = auto() # $()
    DOLLAR_PAREN_PAREN_ARITH_CONTROL = auto() # $(())
    QUOTED_CONTROL = auto() # $(())

#     STRING_CHAR = auto() # a=stringlit # excluded because I don't know what to do with this
    ESCAPED_CHAR = auto() # escaped
    RAW_COMMAND = auto() # like echo

@dataclass(frozen=True)
class Command:
    name: str
    def __str__(self):
        return f'command({self.name})'

def count_nodes(asts, count: Counter[NodeVariant]):
    match asts:
        case NodeWSource(node=subnode):
            count_nodes(subnode, count)
        case CArgChar():
            pass
        case EArgChar():
            count[NodeVariant.ESCAPED_CHAR] += 1
        case TArgChar():
            count[NodeVariant.HOME_TILDE_CONTROL] += 1
        case AArgChar(arg=more):
            count_nodes(more, count)
            count[NodeVariant.DOLLAR_PAREN_PAREN_ARITH_CONTROL] += 1
        case VArgChar(arg=more):
            count[NodeVariant.VARIABLE_USE] += 1
            count_nodes(more, count)
        case QArgChar(arg=more):
            count[NodeVariant.QUOTED_CONTROL] += 1
            count_nodes(more, count)
        case BArgChar(node=subnode):
            count[NodeVariant.DOLLAR_PAREN_SHELL_CONTROL] += 1
            count_nodes(subnode, count)
        case PipeNode(items=subnodes):
            count_nodes(subnodes, count)
            count[NodeVariant.PIPELINE] += 1
        case SubshellNode(body=subnode):
            count_nodes(subnode, count)
            count[NodeVariant.SUBSHELL_COMMAND] += 1
        case NotNode(body=subnode):
            count_nodes(subnode, count)
            count[NodeVariant.NEGATE_COMMAND] += 1
        case RedirNode(node=subnode):
            count_nodes(subnode, count)
            count[NodeVariant.REDIRECTION] += 1
        case BackgroundNode(node=subnode):
            count_nodes(subnode, count)
            count[NodeVariant.BACKGROUND] += 1
        case DefunNode(body=subnode):
            count_nodes(subnode, count)
            count[NodeVariant.FUNCTION_COMMAND] += 1
        case AndNode(left_operand=l, right_operand=r):
            count_nodes([l, r], count)
            count[NodeVariant.AND_COMMAND] += 1
        case OrNode(left_operand=l, right_operand=r):
            count_nodes([l, r], count)
            count[NodeVariant.OR_COMMAND] += 1
        case SemiNode(left_operand=l, right_operand=r):
            count_nodes([l, r], count)
        case WhileNode(test=l, body=r):
            count_nodes([l, r], count)
            count[NodeVariant.WHILE_COMMAND] += 1
        case IfNode(cond=t, then_b=thn, else_b=els):
            count_nodes([t, thn, els], count)
            count[NodeVariant.IF_COMMAND] += 1
        case ForNode(argument=lolo_argchar, body=subnode):
            count_nodes(lolo_argchar, count)
            count_nodes(subnode, count)
            count[NodeVariant.FOR_COMMAND] += 1
        case CaseNode(argument=argchars, cases=cases):
            count[NodeVariant.CASE_COMMAND] += 1
            for node in argchars:
                count_nodes(node, count)
            for c in cases:
                count_nodes(c['cbody'], count)
        case AssignNode(val=argchars):
            count[NodeVariant.ASSIGNMENT] += 1
            count_nodes(argchars, count)
        case FileRedirNode(arg=argchars):
            count[NodeVariant.FILE_REDIRECTION] += 1
            count_nodes(argchars, count)
        case DupRedirNode(arg=argchars):
            count[NodeVariant.DUP_REDIRECTION] += 1
        case HeredocRedirNode(arg=argchars):
            count[NodeVariant.HEREDOC_REDIRECTION] += 1
            count_nodes(argchars, count)
        case CommandNode(arguments=lolo_argchar, assignments=assignments, redir_list=redir_list):
            if len(lolo_argchar) > 0 and all(isinstance(c, CArgChar) for c in lolo_argchar[0]):
                command_name = ''.join(str(c) for c in lolo_argchar[0])
                count[Command(command_name)] += 1
            count_nodes(assignments, count)
            count_nodes(redir_list, count)
            count_nodes(lolo_argchar, count)
        case [*subnodes]:
            for node in subnodes:
                count_nodes(node, count)
        case other:
            raise Exception(f"oops: {other} of type {type(other)}")

if __name__ == '__main__':
    p = "script.sh"
    asts = parse_shell_script(p)
    count = Counter()
    count_nodes(asts, count)
    print(count)
