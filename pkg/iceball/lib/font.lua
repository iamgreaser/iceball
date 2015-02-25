fonts = { }
--font_prototype = {"font" = {[16] = {fontdata}}}

--fontname should look like this: "filename:x" where x is the index (starting from 0)
--example: "propaganda:2" if there is a propaganda.ttf with 3 styles
function common.font_load(fontname, ptsize)
  local font_index = 0
  colon_index = fontname:match'^.*():'
  if colon_index and colon_index ~= #fontname then
      font_index =fontname:sub(colon_index+1, #fontname)
      font_index = math.floor(tonumber(font_index) or error("Could not cast to number.'"))
  end

  if not DIR_PKG_TTF then
    error("Variable DIR_PKG_TTF not set, can not continue!")
  end

  local filename = DIR_PKG_TTF.."/"..fontname..".ttf"
  local font = common.font_ttf_load(filename, ptsize)
  return font
end

--ptsize = 16
function common.font_get(fontname, ptsize)
  if fonts[fontname] then
    if fonts[fontname][ptsize] then
      return fonts[fontname][ptsize]
    end
  end

  fonts[fontname] = {}
  -- fonts[fontname][ptsize] = {}
  local font = common.font_load(fontname, ptsize)
  fonts[fontname][ptsize] = font
  return font
end

do
	if not DIR_PKG_TTF then
		DIR_PKG_TTF = client.base_dir.."/ttf"
	end

end

if client then
  
--ptsize = 16, font = "OpenSans-Regular"
function client.font_render_text(x, y, text, color, ptsize, fontname)
  if not FONT_DEFAULT or not fonts then
    error("Variable FONT_DEFAULT not set, can not continue!")
  end
  if not client then
    error("Function render_text is client-only!")
  end
  local ttf_font = common.font_get(fontname, ptsize)
  local image = client.font_render_to_texture(ttf_font, text, color)
  client.img_blit(image, x, y)
end
end
