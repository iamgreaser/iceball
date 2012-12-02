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

#include "common.h"

char *path_filter(const char *instr)
{
#ifdef WIN32
	// TODO? filter for Windows?
#endif
	return strdup(instr);
}

int path_get_type(const char *path)
{
	const char *v;
	
	// check: is this null?
	if(path == NULL)
		return PATH_ERROR_BADCHARS;
	
	// check: are all chars valid?
	for(v = path; *v != '\0'; v++)
	{
		// -.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_abcdefghijklmnopqrstuvwxyz
		if(*v >= 'a' && *v <= 'z')
			continue;
		if(*v >= 'A' && *v <= 'Z')
			continue;
		if(*v >= '0' && *v <= '9')
			continue;
		if(*v == '/' || *v == '-' || *v == '.' || *v == '[' || *v == ']' || *v == '_')
			continue;
		
		return PATH_ERROR_BADCHARS;
	}
	
	// check: clsave/vol/../pub/config.json should not happen!
	if(path[0] == '.' || strstr(path, "/.") != NULL)
		return PATH_ERROR_ACCDENIED;
	
	// now start checking paths
	if(!memcmp(path,mod_basedir,strlen(mod_basedir)))
		return PATH_PKG_BASEDIR;
	if(!memcmp(path,"pkg/",4))
		return PATH_PKG;
	if(!memcmp(path,"clsave/pub/",11))
		return PATH_CLSAVE_PUBLIC;
	if(!memcmp(path,"clsave/vol/",11))
		return PATH_CLSAVE_VOLATILE;
	if((!memcmp(path,"clsave/",7))
		&& (!memcmp(path+7,mod_basedir+4,strlen(mod_basedir+4))))
	{
		if((!memcmp(path+3+strlen(mod_basedir),"vol/",4))
			|| (!memcmp(path+3+strlen(mod_basedir),"/vol/",5)))
			return PATH_CLSAVE_BASEDIR_VOLATILE;
		else
			return PATH_CLSAVE_BASEDIR;
	}
	
	if(!memcmp(path,"svsave/pub/",11))
		return PATH_SVSAVE_PUBLIC;
	if(!memcmp(path,"svsave/vol/",11))
		return PATH_SVSAVE_VOLATILE;
	if((!memcmp(path,"svsave/",7))
		&& (!memcmp(path+7,mod_basedir+4,strlen(mod_basedir+4))))
	
	{
		if((!memcmp(path+3+strlen(mod_basedir),"vol/",4))
			|| (!memcmp(path+3+strlen(mod_basedir),"/vol/",5)))
			return PATH_SVSAVE_BASEDIR_VOLATILE;
		else
			return PATH_SVSAVE_BASEDIR;
	}
	
	return PATH_ERROR_ACCDENIED;
}

int path_type_client_local(int type)
{
	return type == PATH_CLSAVE_BASEDIR
		|| type == PATH_CLSAVE_PUBLIC
		|| type == PATH_CLSAVE_VOLATILE
		|| type == PATH_CLSAVE_BASEDIR_VOLATILE;
}

int path_type_client_readable(int type)
{
	return path_type_client_local(type)
		|| type == PATH_PKG
		|| type == PATH_PKG_BASEDIR;
}

int path_type_client_writable(int type)
{
	return type == PATH_CLSAVE_BASEDIR_VOLATILE
		|| type == PATH_CLSAVE_VOLATILE;
}

int path_type_server_readable(int type)
{
	return type == PATH_SVSAVE_BASEDIR
		|| type == PATH_SVSAVE_PUBLIC
		|| type == PATH_SVSAVE_VOLATILE
		|| type == PATH_SVSAVE_BASEDIR_VOLATILE
		|| type == PATH_PKG
		|| type == PATH_PKG_BASEDIR;
}

int path_type_server_writable(int type)
{
	return type == PATH_SVSAVE_BASEDIR_VOLATILE
		|| type == PATH_SVSAVE_VOLATILE;
}
