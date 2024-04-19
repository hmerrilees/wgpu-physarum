struct Particle {
  pos : vec2<f32>,
  vel : vec2<f32>,
};

struct SimParams {
  diffusionRate : f32,
  sensorAngle : f32,
  sensorDistance : f32,
  rotationAngle : f32,
  stepSize : f32,
};

@group(0) @binding(0) var<uniform> params : SimParams;
@group(0) @binding(1) var<storage, read> particlesSrc : array<Particle>;
@group(0) @binding(2) var<storage, read_write> particlesDst : array<Particle>;
@group(0) @binding(3) var substrate : texture_storage_2d<rgba16float, read_write>;

// https://github.com/austinEng/Project6-Vulkan-Flocking/blob/master/data/shaders/computeparticles/particle.comp
@compute
@workgroup_size(64)
fn main(@builtin(global_invocation_id) global_invocation_id: vec3<u32>) {
  let total = arrayLength(&particlesSrc);
  let index = global_invocation_id.x;
  if (index >= total) {
    return;
  }

  var vPos : vec2<f32> = particlesSrc[index].pos;
  var vVel : vec2<f32> = particlesSrc[index].vel;

  var angle = atan2(vVel.y, vVel.x);

  // Physarum sensor
    var sensorAngle = params.sensorAngle;

    var left_sensor_angle = angle + sensorAngle;
    var right_sensor_angle = angle - sensorAngle;

var left_sensor_offset = vec2<f32>(cos(left_sensor_angle), sin(left_sensor_angle));
var center_sensor_offset = vec2<f32>(cos(angle), sin(angle));
var right_sensor_offset = vec2<f32>(cos(right_sensor_angle), sin(right_sensor_angle));

var texture_dims = textureDimensions(substrate);

var texture_pos = vec2<f32>((vPos.x + 1.0) * 0.5 * f32(texture_dims.x), (vPos.y + 1.0) * 0.5 * f32(texture_dims.y));

var left_sensor_pos = texture_pos + left_sensor_offset * params.sensorDistance;
var center_sensor_pos = texture_pos + center_sensor_offset * params.sensorDistance;
var right_sensor_pos = texture_pos + right_sensor_offset * params.sensorDistance;

var left_sensor_color = textureLoad(substrate, vec2<u32>(left_sensor_pos));
var center_sensor_color = textureLoad(substrate, vec2<u32>(center_sensor_pos));
var right_sensor_color = textureLoad(substrate, vec2<u32>(right_sensor_pos));

var left_sensor_intensity = (left_sensor_color.r + left_sensor_color.g + left_sensor_color.b) / 3.0;
var center_sensor_intensity = (center_sensor_color.r + center_sensor_color.g + center_sensor_color.b) / 3.0;
var right_sensor_intensity = (right_sensor_color.r + right_sensor_color.g + right_sensor_color.b) / 3.0;

// TODO check
// center greatest, otherwise check left and right
if (center_sensor_intensity > left_sensor_intensity && center_sensor_intensity > right_sensor_intensity) {
    // do nothing
    } else if (left_sensor_intensity > right_sensor_intensity) {
    angle += params.rotationAngle;
    } else if (right_sensor_intensity > left_sensor_intensity) {
    angle -= params.rotationAngle;
}
// take step
vVel = vec2<f32>(cos(angle), sin(angle)) * params.stepSize;
vPos += vVel;




  // Wrap around boundary
  if (vPos.x < -1.0) {
    vPos.x = 1.0;
  }
  if (vPos.x > 1.0) {
    vPos.x = -1.0;
  }
  if (vPos.y < -1.0) {
    vPos.y = 1.0;
  }
  if (vPos.y > 1.0) {
    vPos.y = -1.0;
  }

  // draw trail
  var x = u32((vPos.x + 1.0) * 0.5 * f32(textureDimensions(substrate).x));
  var y = u32((vPos.y + 1.0) * 0.5 * f32(textureDimensions(substrate).y));

  // if white within <3 tiles, flip direction and take a step
  var accum = vec3<f32>(0.0, 0.0, 0.0);



  // add .1 to color
      if (x < textureDimensions(substrate).x && y < textureDimensions(substrate).y) {
        var color = textureLoad(substrate, vec2<u32>(x, y));
        color.r = min(color.r + 0.1, 1.0);
        color.g = min(color.g + 0.1, 1.0);
        color.b = min(color.b + 0.1, 1.0);
        textureStore(substrate, vec2<u32>(x, y), color);
      }

  // Write back
  particlesDst[index] = Particle(vPos, vVel);
}


// kernel blur
@compute
@workgroup_size(16, 16)
fn blur(@builtin(global_invocation_id) global_invocation_id: vec3<u32>) {
  var texture_dims = textureDimensions(substrate);
  var x = global_invocation_id.x;
  var y = global_invocation_id.y;

  if (x >= texture_dims.x || y >= texture_dims.y) {
    return;
  }

  var color = textureLoad(substrate, vec2<u32>(x, y));
  var sum = vec3<f32>(0.0, 0.0, 0.0);
  var count = 0;

  for (var dx : i32 = -1; dx <= 1; dx = dx + 1) {
    for (var dy : i32 = -1; dy <= 1; dy = dy + 1) {
      var nx = u32(i32(x) + dx);
      var ny = u32(i32(y) + dy);
      if (nx >= 0 && nx < texture_dims.x && ny >= 0 && ny < texture_dims.y) {
        sum = sum + textureLoad(substrate, vec2<u32>(u32(nx), u32(ny))).rgb;
        count = count + 1;
      }
    }
  }

  workgroupBarrier(); // todo check

  var val = sum / f32(count) *  (1.0 - params.diffusionRate);
  color = vec4<f32>(val, 1.0);
  textureStore(substrate, vec2<u32>(x, y), color);
}