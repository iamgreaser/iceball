do

DIR_CHENMOD = "pkg/gm/chen/"
DIR_PKG_IT = "pkg/gm/chen/"

-- need string.split
dofile("pkg/base/lib_util.lua")

local chen_padding = {
	":3", "^_^", "HONK", "MEOW", "HONK", "Yum!",
}

function chenpick(l)
	return l[math.floor(math.random()*#l)+1]
end

function chenify_msg(msg)
	local l = string.split(msg, " ")
	local i
	local maxchen = math.max(2, math.floor(math.random()*#l*0.8+1))

	local docaps = true
	for i=1,#l do
		l[i] = l[i]:lower()
		if docaps then
			l[i] = l[i]:sub(1,1):upper() .. l[i]:sub(2)
			docaps = false
		end

		if i == #l or math.random() < 0.25 then
			l[i] = l[i].."!"
			docaps = true
		end
	end
	for i=1,maxchen do
		table.insert(l, math.floor(math.random()*(#l+1)+1), chenpick(chen_padding))
	end
	table.insert(l, chenpick(chen_padding))
	return table.concat(l, " ")
end

if client then
	common.version.str = "CHEEEEEN"
	client.renderer = "ChenGL"
	client.mk_set_title("Chenball")

	local s_fetch_block = common.fetch_block
	local has_chenned_bugs = false
	function common.fetch_block(ftype, fname)
		if VERSION_BUGS and string.split and not has_chenned_bugs then
			local k, v
			for k, v in pairs(VERSION_BUGS) do
				if v.renderer == "gl" then
					v.renderer = "ChenGL"
				end

				v.msg = chenify_msg(v.msg)
			end
			has_chenned_bugs = true
		end

		return s_fetch_block(ftype, fname)
	end
end

end

