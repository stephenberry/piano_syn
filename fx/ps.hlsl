float4 keys0, keys1;

float white_keys(float3 p)
{
  int k = 2 * floor((p.x + 0.03) / 0.06) + 132;
  if (!all(keys0 - k) || !all(keys1 - k))
  {
    float2 o = p.yz - float2(0, 0.2);
    p.y = o.x * cos(0.08) - o.y * sin(0.08);
    p.z = o.x * sin(0.08) + o.y * cos(0.08) + 0.2;
  }

  float ox = p.x;
  p.x = fmod(abs(ox + 0.03), 0.06) - 0.03;
  float d1 = length(max(abs(p) - float3(0.024, 0.002, 0.2), 0)) - 0.005;
  p.y += 0.04;
  float d2 = length(max(abs(p) - float3(0.024, 0.04, 0.18), 0)) - 0.002;

  int r = fmod(floor(ox / 0.06) + 70, 7);
  float ret = min(d1, d2);
  if (r != 0 && r != 4)
  {
    p.x = fmod(abs(ox), 0.06) - 0.03;
    p.z -= 0.1;
    float3 t = abs(p) - float3(0.02, 0.1, 0.15);
    float d3 = min(max(t.x, max(t.y, t.z)), 0) + length(max(t, 0));
    ret = max(min(d1, d2), -d3);
  }
  return ret;
}

float black_keys(float3 p)
{
  int k = 2 * floor(p.x / 0.06) + 133;
  if (!all(keys0 - k) || !all(keys1 - k))
  {
    float2 o = p.yz - float2(0, 0.1);
    p.y = o.x * cos(0.1) - o.y * sin(0.1) + 0.012;
    p.z = o.x * sin(0.1) + o.y * cos(0.1) + 0.1;
  }

  int r = fmod(floor(p.x / 0.06) + 70, 7);
  float ret = 1000;
  if (r != 0 && r != 4)
  {
    p.x = fmod(abs(p.x), 0.06) - 0.03;
    p.x *= (1 + 10 * p.y);
    p.y += 0.5 * p.z * p.z;
    p.z -= 0.08;
    p.y -= 0.014;
    ret = length(max(abs(p) - float3(0.01, 0.03, 0.122), 0)) - 0.003;
  }
  return ret;
}

float boards(float3 p)
{
  p.z += 0.3;
  p.y += 0.065;
  float d1 = length(max(abs(p) - float3(2, 0.05, 0.02), 0)) - 0.01;  
  p.z -= 0.53;
  float d2 = length(max(abs(p) - float3(2, 0.13, 0.007), 0)) - 0.01;
  return min(d1, d2);
}

float2 piano(float3 p)
{
  float d1 = white_keys(p);
  float d2 = black_keys(p);
  float d3 = boards(p);
  float2 t = d1 < d2 ? float2(d1, 1) : float2(d2, 2);
  return t.x < d3 ? t : float2(d3, 3);
}

float4 ray_marching(float3 ro, float3 rd)
{
  float4 ret = float4(ro, -1);
  for (int i = 0; i < 32; ++i)
  {
    float2 dm = piano(ro);
    if (dm.x < 0.001) ret = float4(ro, dm.y);
    ro += rd * dm.x;
  }
  return ret;
}

float3 brdf(float3 diff, float m, float3 N, float3 L, float3 V)
{
  float3 H = normalize(V + L);
  float3 F = 0.05 + 0.95 * pow(1 - dot(V, H), 5);
  float3 R = F * pow(max(dot(N, H), 0), m);
  return diff + R * (m + 8) / 8;
}

float3 lit_white_keys(float3 p, float3 N)
{
  float3 V = normalize(float3(0, 3, -5));
  float3 L = normalize(float3(-3, 3, -1));
  float3 C = 2 * brdf(0.9, 50, N, L, V) * max(dot(N, L), 0.1);
  float ao = 0;
  ao += 0.5 * (0.02 - piano(p + 0.02 * N).x);
  ao += 0.25 * (0.04 - piano(p + 0.04 * N).x);
  ao += 0.125 * (0.06 - piano(p + 0.06 * N).x);
  ao = max(1 - 50 * ao, 0.2);
  float shadow = 0;
  shadow += black_keys(p + 0.01 * L).x;
  shadow = min(60 * shadow, 1.0);
  return C * ao * max(shadow, 0.5);
}

float3 lit_black_keys(float3 p, float3 N)
{
  float3 V = normalize(float3(0, 3, -5));
  float3 L = normalize(float3(0, 3, 2));
  return 2 * brdf(0, 50, N, L, V);
}

float3 lit_boards(float3 p, float3 N)
{
  float3 V = normalize(float3(0, 3, -5));
  float3 L = normalize(float3(0, 3, 2));
  return max(brdf(0, 50, N, L, V), 0.005);
}

float4 do_lighting(float3 ro, float3 rd)
{
  float4 rm = ray_marching(ro, rd);
  float4 ret = 0;
  if (rm.w < 0) ret = float4(0, 0, 0, 0);
  else
  {
    float gx = (piano(rm.xyz + float3(0.0001, 0, 0)) - piano(rm.xyz - float3(0.0001, 0, 0))).x;
    float gy = (piano(rm.xyz + float3(0, 0.0001, 0)) - piano(rm.xyz - float3(0, 0.0001, 0))).x;
    float gz = (piano(rm.xyz + float3(0, 0, 0.0001)) - piano(rm.xyz - float3(0, 0, 0.0001))).x;
    float3 N = normalize(float3(gx, gy, gz));
  
    if (rm.w < 1.5) ret = float4(lit_white_keys(rm.xyz, N), 1);
    else if (rm.w < 2.5) ret = float4(lit_black_keys(rm.xyz, N), 1);
    else ret = float4(lit_boards(rm.xyz, N), 1);
  }
  return ret;
}

float4 ps_main(in float2 u : TEXCOORD) : COLOR
{
  float2 p = (u - 0.5) * 2 * float2(-1, 0.2);

  float3 ro = float3(0, 3, -5);
  float3 rt = float3(0, 0, 0);
  float3 cd = normalize(rt - ro);
  float3 cr = normalize(cross(cd, float3(0, 1, 0)));
  float3 cu = cross(cr, cd);

  float3 rd = normalize(p.x * cr + p.y  * cu + 5 * cd);
  float4 radiance = do_lighting(ro, rd);

  float3 col = 0.06 - 0.06 * length(p - float2(0.2, 0.3));
  col = lerp(col, radiance.rgb, radiance.a);
  return float4(pow(col, 0.45), 1);
}
