#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include <windows.h>

char *ib_base_fn = NULL;
char *ib_conn = NULL;

int fail_badly(void)
{
	MessageBox(NULL,
		"An error occurred while trying to access the registry.\r\n"
		"Handler is not installed."
		, "iceball:// URL installer", MB_OK | MB_APPLMODAL | MB_ICONSTOP);
	
	return 2;
}

int set_hkcr_key(char *key, char *ent, char *value)
{
	HKEY hk;

	int e_open = RegOpenKeyEx(HKEY_CURRENT_USER, key, 0, KEY_ALL_ACCESS, &hk);
	if(e_open != ERROR_SUCCESS)
	{
		int e_open = RegCreateKeyEx(HKEY_CURRENT_USER, key, 0, "", REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &hk, NULL);
		if(e_open != ERROR_SUCCESS)
		{
			printf("failure when creating \"%s\": %i (%08X)\n", key, e_open, e_open);
			fflush(stdout);
			return 1;
		}
	}

	int e_setv = RegSetValueEx(hk, ent, 0, REG_SZ, value, strlen(value)+1);
	if(e_setv != ERROR_SUCCESS)
	{
		printf("failure when setting \"%s\": %i (%08X)\n", key, e_setv, e_setv);
		fflush(stdout);
		return 1;
	}
	
	int e_close = RegCloseKey(hk);
	if(e_close != ERROR_SUCCESS)
	{
		printf("failure when closing \"%s\": %i (%08X)\n", key, e_close, e_close);
		fflush(stdout);
		return 1;
	}
}

int main(int argc, char *argv[])
{
	if(IDCANCEL == MessageBox(NULL,

		"This program will make iceball:// URLs work,\r\n"
		"which means that you will be able to click on the links in the Server List,\r\n"
		"and they will actually run Iceball.\r\n"
		"\r\n"
		"Press Cancel at any time if you do not want to do this."
		, "iceball:// URL installer", MB_OKCANCEL | MB_APPLMODAL | MB_ICONINFORMATION))
			return 1;
	
	switch(MessageBox(NULL,

		"Do you want the Hardware Accelerated OpenGL renderer?\r\n"
		"\r\n"
		"If you don't know what this is, just click Yes.\r\n"

		, "iceball:// URL installer", MB_YESNOCANCEL | MB_APPLMODAL | MB_ICONQUESTION))
	{
		case IDYES:
			ib_base_fn = "iceball-gl";
			break;
		case IDNO:
			ib_base_fn = "iceball";
			break;
		default:
			return 1;
	}
	
	switch(MessageBox(NULL,

		"Do you want to use ENet?\r\n"
		"\r\n"
		"ENet runs a lot better than the TCP protocol,\r\n"
		"but doesn't work over IPv6 at the moment.\r\n"
		"\r\n"
		"If you don't know what any one of those 3 things are, just click Yes.\r\n"

		, "iceball:// URL installer", MB_YESNOCANCEL | MB_APPLMODAL | MB_ICONQUESTION))
	{
		case IDYES:
			ib_conn = "-c";
			break;
		case IDNO:
			ib_conn = "-C";
			break;
		default:
			return 1;
	}

	char runbuf[2048];
	char cwdbuf[1536] = "";
	_getcwd(cwdbuf, 1535);
	sprintf(runbuf, "\"%s\\%s.exe\" %s \"%%1\"", cwdbuf, ib_base_fn, ib_conn);

	char msgboxbuf[2048+1024];

	sprintf(msgboxbuf,
		"When you click OK, iceball:// URLs will run this command:\r\n\r\n"
		"%s\r\n\r\n"
		"Click OK to continue, or click Cancel to abort and possibly try again.",
			runbuf);

	if(IDCANCEL == MessageBox(NULL,
		msgboxbuf
		, "iceball:// URL installer", MB_OKCANCEL | MB_APPLMODAL | MB_ICONEXCLAMATION))
			return 1;
	
	// Install it!
	if(set_hkcr_key("Software\\Classes\\iceball\\", NULL, "URL:Iceball Protocol Handler")) return fail_badly();
	if(set_hkcr_key("Software\\Classes\\iceball\\", "URL Protocol", "")) return fail_badly();
	if(set_hkcr_key("Software\\Classes\\iceball\\shell\\open\\command\\", NULL, runbuf)) return fail_badly();

	// Nothing more we can do.
	MessageBox(NULL,
		"iceball:// URL handler successfully installed."
		, "iceball:// URL installer", MB_OK | MB_APPLMODAL | MB_ICONINFORMATION);
	return 0;
}

