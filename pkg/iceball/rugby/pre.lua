do
	local s_model_load = model_load
	function model_load(mdict, ...)
		print(mdict)
		if mdict.kv6 and mdict.kv6.name == "bomb.kv6" then
			return s_model_load ({
				lua = {
					bdir = "pkg/iceball/rugby",
					name = "mdl_ball.lua",
				},
			}, {"lua"})
		else
			return s_model_load(mdict, ...)
		end
	end
end

