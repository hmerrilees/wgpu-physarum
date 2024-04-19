@group(0) @binding(0) var substrate : texture_storage_2d<rgba16float, read>;

@vertex
fn substrate_vs(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {
  var positions = array<vec2<f32>, 3>(
    vec2<f32>(-1.0, -1.0),
    vec2<f32>(3.0, -1.0),
    vec2<f32>(-1.0, 3.0)
  );
  return vec4<f32>(positions[in_vertex_index], 0.0, 1.0);
}


@fragment
fn substrate_fs(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
  let texCoords = pos.xy * 0.5 + 0.5;
  return textureLoad(substrate, vec2<i32>(texCoords * vec2<f32>(textureDimensions(substrate))));
}

