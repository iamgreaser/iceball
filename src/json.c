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

// syntax is as per the stuff down the right hand side of http://json.org/
// and is reproduced purely for reference
// there's also train track syntax on that page, too

// note, this assumes 8-bit ASCII.
// UTF-8 is supported BUT you have to parse it yourself;
// having said that, '\u' chars should hopefully encode to UTF-8.

// one exception to strict JSON conformance:
// this DOES allow the last element of an array or object to have a trailing comma.
// the JSON writer, however, does not abuse that feature of this parser.
// furthermore, the parser WILL warn you if you do this.

#include "common.h"

int json_line_count = 1;

int json_parse_value(lua_State *L, const char **p);

void json_skip_whitespace(const char **p)
{
	int lastwasr = 0;
	
	while(**p == ' ' || **p == '\t' || **p == '\n' || **p == '\r')
	{
		if((**p == '\n' && !lastwasr) || **p == '\r')
		{
			json_line_count++;
			//printf("%i\n",json_line_count);
		}
		
		lastwasr = (**p == '\r');
		(*p)++;
	}
}

int json_parse_hex4(lua_State *L, const char **p, int *uchr)
{
	int i;
	*uchr = 0;
	for(i = 0; i < 4; i++)
	{
		*uchr <<= 4;
		if(**p >= '0' && **p <= '9')
			*uchr += (**p - '0');
		else if(**p >= 'a' && **p <= 'f')
			*uchr += (**p - 'a') + 10;
		else if(**p >= 'A' && **p <= 'F')
			*uchr += (**p - 'A') + 10;
		else {
			fprintf(stderr, "%i: expected hex digit\n", json_line_count);
			return 1;
		}
	}
	return 0;
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
int json_parse_string(lua_State *L, const char **p)
{
	if(*((*p)++) != '\"')
	{
		fprintf(stderr, "%i: expected '\"'\n", json_line_count);
		return 1;
	}
	
	int sbuf_pos = 0;
	int sbuf_len = 64;
	char *sbuf = (char*)malloc(sbuf_len);
	// TODO: throughout this code, check if sbuf is NULL
	int uchr = 0;
	int lastwasr = 0;
	
	while(**p != '\"')
	{
		if(**p == '\\')
		{
			switch(*(++(*p)))
			{
				case '\"':
					uchr = '\"';
					break;
				case '\\':
					uchr = '\\';
					break;
				case '/':
					uchr = '/';
					break;
				case 'b':
					uchr = '\b';
					break;
				case 'f':
					uchr = '\f';
					break;
				case 'n':
					uchr = '\n';
					if(!lastwasr)
						json_line_count++;
					break;
				case 'r':
					uchr = '\r';
					lastwasr = 2;
					json_line_count++;
					break;
				case 't':
					uchr = '\t';
					break;
				case 'u':
					if(json_parse_hex4(L, p, &uchr))
					{
						free(sbuf);
						return 1;
					}
					break;
				default:
					fprintf(stderr, "%i: invalid token after '\\'\n", json_line_count);
					free(sbuf);
					return 1;
			}
			(*p)++;
		} else if(**p == '\0') {
			fprintf(stderr, "%i: unexpected NUL\n", json_line_count);
			free(sbuf);
			return 1;
		} else {
			uchr = (int)(unsigned char)(*((*p)++));
			if(uchr == 10)
			{
				if(!lastwasr)
					json_line_count++;
			} else if(uchr == 13) {
				lastwasr = 2;
				json_line_count++;
			}
		}
		
		if(lastwasr > 0)
			lastwasr--;
		
		if(sbuf_pos+4 >= sbuf_len)
		{
			sbuf_len <<= 1;
			sbuf = (char*)realloc(sbuf, sbuf_len);
			//printf("%i %016llX\n", sbuf_len, sbuf);
		}
		
		if(uchr >= 0x01 && uchr <= 0x7F)
		{
			// 0xxxxxxx
			sbuf[sbuf_pos++] = uchr;
		} else if(uchr <= 0x7FF) {
			// 110xxxxx
			// 10xxxxxx
			sbuf[sbuf_pos++] = 0xC0 | (uchr>>6);
			sbuf[sbuf_pos++] = 0x80 | ((uchr)&0x3F);
		} else if(uchr <= 0xFFFF) {
			// 1110xxxx
			// 10xxxxxx
			// 10xxxxxx
			sbuf[sbuf_pos++] = 0xE0 | (uchr>>12);
			sbuf[sbuf_pos++] = 0x80 | ((uchr>>6)&0x3F);
			sbuf[sbuf_pos++] = 0x80 | ((uchr)&0x3F);
		}
	}
	
	(*p)++;
	lua_pushlstring(L, sbuf, sbuf_pos);
	free(sbuf);
	json_skip_whitespace(p);
	return 0;
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
int json_parse_number(lua_State *L, const char **p)
{
	double n = 0.0;
	double sign = 1.0;
	
	if(**p == '-')
	{
		sign = -1.0;
		(*p)++;
	}
	
	if(**p < '0' || **p > '9')
	{
		fprintf(stderr, "%i: expected digit\n", json_line_count);
		return 1;
	}
	
	if(**p == '0')
	{
		(*p)++;
	} else {
		while(**p >= '0' && **p <= '9')
			n = n*10.0 + (*((*p)++) - '0');
	}
	
	if(**p == '.')
	{
		(*p)++;
		
		if(**p < '0' || **p > '9')
		{
			fprintf(stderr, "%i: expected digit\n", json_line_count);
			return 1;
		}
		
		double sub = 0.1;
		
		while(**p >= '0' && **p <= '9')
		{
			n += (*((*p)++) - '0')*sub;
			sub *= 0.1;
		}
	}
	
	if(**p == 'e' || **p == 'E')
	{
		(*p)++;
		
		int esign = 1;
		int e = 0;
		if(**p == '+')
			(*p)++;
		else if(**p == '-')
		{
			esign = -1;
			(*p)++;
		}
		
		if(**p < '0' || **p > '9')
		{
			fprintf(stderr, "%i: expected digit\n", json_line_count);
			return 1;
		}
		
		while(**p >= '0' && **p <= '9')
			e = e*10 + (*((*p)++) - '0');
		
		if(esign < 0)
		{
			while(e > 0)
			{
				n *= 0.1;
				e--;
			}
		} else {
			while(e > 0)
			{
				n *= 10.0;
				e--;
			}
		}
	}
	
	json_skip_whitespace(p);
	
	lua_pushnumber(L, n);
	return 0;
}

// array
//     []
//     [ elements ]
// elements
//     value
//     value , elements
int json_parse_array(lua_State *L, const char **p)
{
	int idx = 1;
	
	if(*((*p)++) != '[')
	{
		fprintf(stderr, "%i: expected '\"'\n", json_line_count);
		return 1;
	}
	
	json_skip_whitespace(p);
	
	lua_newtable(L);
	
	while(**p != ']')
	{
		lua_pushinteger(L, idx++);
		
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
		} else if(**p != ']') {
			fprintf(stderr, "%i: expected ',' or ']'\n", json_line_count);
			lua_pop(L, 1);
			return 1;
		}
	}
	
	(*p)++;
	return 0;
	
}

int json_parse_object(lua_State *L, const char **p);

// value
//     string
//     number
//     object
//     array
//     true
//     false
//     null
int json_parse_value(lua_State *L, const char **p)
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
		if(json_parse_object(L, p))
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
int json_parse_object(lua_State *L, const char **p)
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
			//printf("%s\n", luaL_typename(L, -1));
			return 0;
		}
	}
	printf("bail\n");
	
	lua_pop(L, 1);
	fprintf(stderr, "%i: expected '\"' or '}'\n", json_line_count);
	return 1;
}

int json_parse(lua_State *L, const char *p)
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

int json_load(lua_State *L, const char *fname)
{
	int flen;
	char *buf = net_fetch_file(fname, &flen);
	if(buf == NULL)
		return 1;
	int ret = json_parse(L, buf);
	free(buf);
	return ret;
}

// JSON writing

int json_write_value(lua_State *L, FILE *fp);

/*
	snprintf out %f number
	write out
*/
// would lua_tostring work?
int json_write_number(lua_State *L, FILE *fp)
{
	const char* buf = lua_pushfstring(L, "%f", lua_tonumber(L, -1));
	fwrite(buf, lua_objlen(L, -1), 1, fp);
	lua_pop(L, 2);
	return 0;
}

/*
	write """
	for each char in string {
		if char is "
			write "\""
		if char is \
			write "\\"
		if char is /
			write "\/"
		if char is backspace
			write "\b"
		if char is formfeed
			write "\f"
		if char is newline
			write "\n"
		if char is carriage return
			write "\r"
		if char is tab
			write "\t"
		if char is not printable
			write "\u####"
		else
			write char
	}
	write """
*/
int json_write_string(lua_State *L, FILE *fp)
{
	unsigned int len;
	const char* c = lua_tolstring(L, -1, (size_t *)&len);
	fwrite("\"", 1, 1, fp);
	for(; len > 0; --len)
	{
		if(*c == '"')
			fwrite("\\\"", 2, 1, fp);
		else if(*c == '\\')
			fwrite("\\\\", 2, 1, fp);
		else if(*c == '\b')
			fwrite("\\b", 2, 1, fp);
		else if(*c == '\f')
			fwrite("\\f", 2, 1, fp);
		else if(*c == '\n')
			fwrite("\\n", 2, 1, fp);
		else if(*c == '\r')
			fwrite("\\r", 2, 1, fp);
		else if(*c == '\t')
			fwrite("\\t", 2, 1, fp);
		else if(!isprint(*c))
		{
			char* buf = (char*) malloc(6);
			sprintf(buf, "\\u%4.4X", *((unsigned char*) c));
			fwrite(buf, 6, 1, fp);
		}
		else
			fputc(*c, fp);
		c++;
	}
	fwrite("\"", 1, 1, fp);
	lua_pop(L, 1);
	return 0;
}

/*
	write "{"
	pushnil
	if lua_next {
		json_write_value(stack(-2))
		write ":"
		json_write_value(stack(-1))
		pop
		while lua_next {
			write ","
			json_write_value(stack(-2))
			write ":"
			json_write_value(stack(-1))
			pop
		}
	}
	write "}"
*/
int json_write_table(lua_State *L, FILE *fp)
{
	fwrite("{\r\n", 3, 1, fp);
	lua_pushnil(L);
	if (lua_next(L, -2))
	{
		lua_pushvalue(L, -2);
		json_write_value(L, fp);
		fwrite(": ", 2, 1, fp);
		json_write_value(L, fp);
		while (lua_next(L, -2))
		{
			lua_pushvalue(L, -2);
			fwrite(",\r\n", 3, 1, fp);
			json_write_value(L, fp);
			fwrite(": ", 2, 1, fp);
			json_write_value(L, fp);
		}
		fwrite("\r\n", 2, 1, fp);
	}
	fwrite("}", 1, 1, fp);
	lua_pop(L, 1);
	return 0;
}

/*
	write "["
	pushnil
	if lua_next {
		json_write_value(stack(-1))
		pop
		while lua_next {
			write ","
			json_write_value(stack(-1))
			pop
		}
	}
	write "]"
*/
int json_write_array(lua_State *L, FILE *fp)
{
	fwrite("[", 1, 1, fp);
	lua_pushnil(L);
	if (lua_next(L, -2))
	{
		json_write_value(L, fp);
		while (lua_next(L, -2))
		{
			fwrite(", ", 2, 1, fp);
			json_write_value(L, fp);
		}
	}
	fwrite("]", 1, 1, fp);
	lua_pop(L, 1);
	return 0;
}

/*
	if isboolean && value write "true"
	if isboolean && !value write "false"
	if isnil write "null"
	if istable json_write_table
	if isarray json_write_array
	if isnumber json_write_number
	if isstring json_write_string
	error
*/
int json_write_value(lua_State *L, FILE *fp)
{
	if (lua_isboolean(L, -1))
	{
		if (lua_toboolean(L, -1))
			fwrite("true", 4, 1, fp);
		else
			fwrite("false", 5, 1, fp);
		lua_pop(L, 1);
	}
	else if (lua_isnil(L, -1))
	{
		fwrite("null", 4, 1, fp);
		lua_pop(L, 1);
	}
	else if (lua_istable(L, -1))
	{
		lua_pushnumber(L, 1);
		lua_gettable(L, -2);
		if (lua_isnil(L, -1))
		{
			lua_pop(L, 1);
			json_write_table(L, fp);
		}
		else
		{
			lua_pop(L, 1);
			json_write_array(L, fp);
		}
	}
	else if (lua_isnumber(L, -1))
		json_write_number(L, fp);
	else if (lua_isstring(L, -1))
		json_write_string(L, fp);
	else
		return luaL_error(L, "json_write_value: invalid type");
	return 0;
}

int json_write(lua_State *L, const char *fname)
{
	FILE *fp = fopen(fname, "w");
	if(fp == NULL)
		return luaL_error(L, "json_write: file not opened");
	int ret = json_write_value(L, fp);
	fclose(fp);
	return ret;
}
