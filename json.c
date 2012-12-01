/*
    This file is part of Iceball.

    Iceball is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Iceball is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Iceball.  If not, see <http://www.gnu.org/licenses/>.
*/

// TODO: finish this!
// TODO: write a JSON writer!

// syntax is as per the stuff down the right hand side of http://json.org/
// and is reproduced purely for reference
// there's also train track syntax on that page, too

// note, this assumes 8-bit ASCII.
// UTF-8 is supported BUT you have to parse it yourself;
// having said that, '\u' chars should hopefully encode to UTF-8.

// one exception to strict JSON conformance:
// this DOES allow the last element of an array or object to have a trailing comma.
// the JSON writer (TODO!), however, will not abuse that feature of this parser.
// furthermore, the parser WILL warn you if you do this.

#include "common.h"

int json_line_count = 1;

int json_parse_value(lua_State *L, char **p);

void json_skip_whitespace(char **p)
{
	int lastwasr = 0;
	
	while(**p == ' ' || **p == '\t' || **p == '\n' || **p == '\r')
	{
		if((**p == '\n' && !lastwasr) || **p == '\r')
			json_line_count++;
		
		lastwasr = (**p == '\r');
		(*p)++;
	}
}

// string
//     ""
//     " chars "
// chars
//     char
//     char chars
// char
//     any-Unicode-character-
//         except-"-or-\-or-
//         control-character
//     \"
//     \\ (let's avoid a C warning by placing this note here...)
//     \/
//     \b
//     \f
//     \n
//     \r
//     \t
//     \u four-hex-digits 
int json_parse_string(lua_State *L, char **p)
{
	if(*((*p)++) != '\"')
	{
		fprintf(stderr, "%i: expected '\"'\n", json_line_count);
		return 1;
	}
	
	fprintf(stderr, "%i: TODO: string parsing\n", json_line_count);
	return 1;
}

// number
//     int
//     int frac
//     int exp
//     int frac exp 
// int
//     digit
//     digit1-9 digits
//     - digit
//     - digit1-9 digits 
// frac
//     . digits
// exp
//     e digits
// digits
//     digit
//     digit digits
// e
//     e
//     e+
//     e-
//     E
//     E+
//     E-
int json_parse_number(lua_State *L, char **p)
{
	fprintf(stderr, "%i: TODO: number parsing\n", json_line_count);
	return 1;
}

// array
//     []
//     [ elements ]
// elements
//     value
//     value , elements
int json_parse_array(lua_State *L, char **p)
{
	if(*((*p)++) != '[')
	{
		fprintf(stderr, "%i: expected '\"'\n", json_line_count);
		return 1;
	}
	
	json_skip_whitespace(p);
	
	lua_newtable(L);
	
	while(**p != ']')
	{
		if(json_parse_value(L, p))
		{
			lua_pop(L, 2);
			return 1;
		}
		
		lua_settable(L, -3);
		
		if(**p == ',')
		{
			(*p)++;
			json_skip_whitespace(p);
			if(**p == ']')
				fprintf(stderr, "%i: warning: trailing ',' in array; not compliant!\n"
					, json_line_count);
		}
	}
	
	(*p)++;
	return 0;
	
}

int json_parse_object(lua_State *L, char **p);

// value
//     string
//     number
//     object
//     array
//     true
//     false
//     null
int json_parse_value(lua_State *L, char **p)
{
	if(**p == 't')
	{
		if((*p)[1] != 'r' || (*p)[2] != 'u' || (*p)[3] != 'e')
		{
			fprintf(stderr, "%i: expected \"true\"\n", json_line_count);
			return 1;
		}
		*p += 4;
		lua_pushboolean(L, 1);
	} else if(**p == 'f') {
		if((*p)[1] != 'a' || (*p)[2] != 'l' || (*p)[3] != 's' || (*p)[4] != 'e')
		{
			fprintf(stderr, "%i: expected \"false\"\n", json_line_count);
			return 1;
		}
		*p += 5;
		lua_pushboolean(L, 0);
	} else if(**p == 'n') {
		if((*p)[1] != 'u' || (*p)[2] != 'l' || (*p)[3] != 'l')
		{
			fprintf(stderr, "%i: expected \"null\"\n", json_line_count);
			return 1;
		}
		*p += 4;
		lua_pushnil(L);
	} else if(**p == '{') {
		if(json_parse_value(L, p))
			return 1;
	} else if(**p == '[') {
		if(json_parse_array(L, p))
			return 1;
	} else if(**p == '"') {
		if(json_parse_string(L, p))
			return 1;
	} else if((**p >= '0' && **p <= '9') || **p == '-') {
		if(json_parse_number(L, p))
			return 1;
	} else {
		fprintf(stderr, "%i: expected value\n", json_line_count);
		return 1;
	}
	
	json_skip_whitespace(p);
	
	return 0;
}

// object
//     {}
//     { members } 
// members
//     pair
//     pair , members
// pair
//     string : value
int json_parse_object(lua_State *L, char **p)
{
	if(*((*p)++) != '{')
	{
		fprintf(stderr, "%i: expected '\"'\n", json_line_count);
		return 1;
	}
	
	json_skip_whitespace(p);
	
	lua_newtable(L);
	
	if(**p == '}')
	{
		(*p)++;
		json_skip_whitespace(p);
		return 0;
	}
	
	while(**p == '"')
	{
		json_parse_string(L, p);
		if(*((*p)++) != ':')
		{
			fprintf(stderr, "%i: expected ':'\n", json_line_count);
			lua_pop(L, 1);
			return 1;
		}
		json_skip_whitespace(p);
		if(json_parse_value(L, p))
		{
			lua_pop(L, 2);
			return 1;
		}
		
		lua_settable(L, -3);
		
		if(**p == ',')
		{
			(*p)++;
			json_skip_whitespace(p);
			if(**p == '}')
				fprintf(stderr, "%i: warning: trailing ',' in object; not compliant!\n"
					, json_line_count);
		}
		
		if(**p == '}')
		{
			(*p)++;
			json_skip_whitespace(p);
			return 0;
		}
	}
	
	lua_pop(L, 1);
	fprintf(stderr, "%i: expected '\"' or '}'\n", json_line_count);
	return 1;
}

int json_parse(lua_State *L, char *p)
{
	json_line_count = 1;
	
	json_skip_whitespace(&p);
	if(json_parse_object(L, &p))
		return 1;
	
	if(*p != '\0')
	{
		lua_pop(L, 1);
		return 1;
	}
	
	return 0;
}
