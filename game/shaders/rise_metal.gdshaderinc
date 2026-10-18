// Shared by both arrival platforms: identical silver colour and concentric etching.
vec3 rise_silver(float radius){
 return vec3(.39,.46,.44)+step(.96,fract(radius*.32))*.1;
}
