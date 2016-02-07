# coding=utf-8
"""
A script to convert the version.json file into a pretty markdown doc.

Public domain where applicable, MIT license everywhere else.
"""
from __future__ import print_function

from itertools import chain
import json
import operator

with open("version.json", "r") as fp:
    versions = json.load(fp)

engine = versions["VERSION_ENGINE"]
bugs = versions["VERSION_BUGS"]

unfixed_bugs = []
fixed_bugs = []

for bug in bugs:
    (fixed_bugs if bug["fix"] else unfixed_bugs).append(bug)

# Sort fixed bugs, latest first
fixed_bugs.sort(key=operator.itemgetter("fix"), reverse=True)

# Sort unfixed bugs, latest first (for consistency, and ease of tracking down)
unfixed_bugs.sort(key=operator.itemgetter("intro"), reverse=True)


def version_string(n):
    z = n & ((1<<10)-1); n >>= 10
    a = n & ((1<<5)-1); n >>= 5
    y = n & ((1<<7)-1); n >>= 7
    x = n & ((1<<5)-1); n >>= 5
    w = n

    s = "%i.%i" % (w, x)
    if y > 0:
        s += ".%i" % y
    if a > 0:
        s += chr(ord('a')+a-1)
    if z > 0:
        s += "-%i" % z

    return s


for bug in chain(fixed_bugs, unfixed_bugs):
    bug["intro"] = version_string(bug["intro"])
    bug["fix"] = version_string(bug["fix"])


with open("../version.md", "w") as fp:
    write = fp.write

    def writeln(b=""):
        write(b + "\n")

    def table(data, columns=None, padding=1):
        if len(data) == 0:
            return

        if columns is None:
            columns = [(k, k.title()) for k in data[0].keys()]
        else:
            new_columns = []
            for column in columns:
                if isinstance(column, basestring):
                    new_columns.append((column, column.title()))
                else:
                    new_columns.append(column)
            columns = new_columns
            del new_columns

        # Determine widths based on longest item (including headers)
        widths = [len(str(k[1])) for k in columns]

        for item in data:
            for x, column in enumerate(columns):
                width = len(str(item[column[0]]))
                if width > widths[x]:
                    widths[x] = width

        # for x, width in enumerate(widths):
        #     widths[x] = width + (padding * 2)

        # Write table
        padding_template = " " * padding
        section_template = padding_template + "%-{0}s" + padding_template
        line_template = "|".join(section_template.format(width) for width in widths)
        line_template = "|" + line_template + "|"

        writeln(line_template % tuple(c[1] for c in columns))
        writeln(line_template % tuple("-" * width for width in widths))

        for item in data:
            writeln(line_template % tuple(item[c[0]] for c in columns))

    writeln("# Versions")
    writeln("----------")
    writeln()
    writeln("*Current version:* %s" % engine["str"])
    writeln()
    writeln("## Bugs")
    writeln("### Unfixed")
    writeln()
    table(unfixed_bugs, ["msg", "intro"])
    writeln()
    writeln("### Fixed")
    writeln()
    table(fixed_bugs)
