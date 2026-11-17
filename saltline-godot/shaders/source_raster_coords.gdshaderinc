vec2 sourceRasterPixel(vec2 pixel,vec2 size,bool y_up){
 return vec2(pixel.x,y_up?pixel.y:size.y-pixel.y);
}
