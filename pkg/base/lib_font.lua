--[[
    This file is part of Ice Lua Components.

    Ice Lua Components is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Ice Lua Components is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Ice Lua Components.  If not, see <http://www.gnu.org/licenses/>.
]]
--TODO: move this to the engine

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
      fontname = fontname:sub(1, colon_index-1)
  end

  if not DIR_PKG_TTF then
    error("Variable DIR_PKG_TTF not set, can not continue!")
  end

  local filename = DIR_PKG_TTF.."/"..fontname..".ttf"
  local font = common.font_ttf_load(filename, ptsize, font_index)
  return font
end

function common.font_get(fontname, ptsize)
  ptsize = ptsize or 16

  if fonts[fontname] then
    if fonts[fontname][ptsize] then
      return fonts[fontname][ptsize]
    end
  end

  fonts[fontname] = {}
  -- fonts[fontname][ptsize] = {}
  local font = common.font_load(fontname, ptsize)
  fonts[fontname][ptsize] = font
  return common.font_get(fontname, ptsize)
end

do
	if not DIR_PKG_TTF then
		DIR_PKG_TTF = client.base_dir.."/ttf"
	end
end

if client then

do
  -- common.font_get(FONT_DEFAULT, 16)
end

function client.font_render_text(x, y, text, color, ptsize, fontname, shadow_color, shadow_size, shadow_x_translate, shadow_y_translate)
  if not FONT_DEFAULT or not fonts then
    error("Variable FONT_DEFAULT not set, can not continue!")
  end
  if not client then
    error("Function render_text is client-only!")
  end

  color = color or 0xFFFFFF
  ptsize = ptsize or 16
  fontname = fontname or FONT_DEFAULT

  shadow_color = shadow_color
  shadow_size = shadow_size or 0
  shadow_x_translate = shadow_x_translate or 1
  shadow_y_translate = shadow_y_translate or 1

  local ttf_font = common.font_get(fontname, ptsize)

  local image, image_shadow
  if shadow_color ~= nil then
    image_shadow = client.font_render_to_texture(ttf_font, text, color, shadow_color, shadow_size)
    client.img_blit(image_shadow, x + shadow_x_translate, y + shadow_y_translate)

    image = client.font_render_to_texture(ttf_font, text, color)
    client.img_blit(image, x, y)
  else
    image = client.font_render_to_texture(ttf_font, text, color)
    client.img_blit(image, x, y)
  end
end

end
