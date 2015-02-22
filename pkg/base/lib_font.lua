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

fonts = {}
--font_prototype = {"font",{[16] = {fontdata}}}

--fontname should look like this: "filename:x" where x is the index
--example: "propaganda:2" if there is a propaganda.ttf with 3 styles
function common.font_load(fontname, ptsize)
  font_index = 0
  colon_index = fontname:match'^.*():'
  if colon_index and colon_index ~= #fontname then
      font_index = tonumber(fontname:sub(colon_index+1, #fontname))
  end

  if not DIR_PKG_TTF then
    error("Variable DIR_PKG_TTF not set, can not continue!")
  end

  filename = DIR_PKG_TTF.."/"..fontname..".ttf"
  return common.font_ttf_load(filename, ptsize, font_index)
end

--ptsize = 16
function common.font_ttf_get(fontname, ptsize)
  if fonts[fontname] then
    if fonts[fontname][ptsize] then
      return fonts[fontname][ptsize]
    end
  end

  local font = common.font_load(fontname, ptsize)
  fonts[fontname][ptsize] = font
  return fonts[fontname].font
end

if client then
--ptsize = 16, font = "OpenSans-regular"
function client.font_render_text(x, y, text, color, ptsize, fontname)
  if not FONT_DEFAULT or not fonts then
    error("Variable FONT_DEFAULT not set, can not continue!")
  end
  if not client then
    luaerror("Function render_text is client-only!")
  end
  local ttf_font = common.font_ttf_get(fontname, ptsize)
  local image = font_ttf_render_to_texture(ttf_font, text, color)
  client.img_blit (image, x, y)
end

end
