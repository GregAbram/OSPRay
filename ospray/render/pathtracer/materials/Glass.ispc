// ======================================================================== //
// Copyright 2009-2016 Intel Corporation                                    //
//                                                                          //
// Licensed under the Apache License, Version 2.0 (the "License");          //
// you may not use this file except in compliance with the License.         //
// You may obtain a copy of the License at                                  //
//                                                                          //
//     http://www.apache.org/licenses/LICENSE-2.0                           //
//                                                                          //
// Unless required by applicable law or agreed to in writing, software      //
// distributed under the License is distributed on an "AS IS" BASIS,        //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. //
// See the License for the specific language governing permissions and      //
// limitations under the License.                                           //
// ======================================================================== //

#include "Material.ih"
#include "render/pathtracer/bsdfs/Dielectric.ih"
#include "texture/TextureParam.ih"

struct Glass
{
  PathTraceMaterial super;

  Medium mediumInside;
  Medium mediumOutside;
};

///////////////////////////////////////////////////////////////////////////////
// Implementation

const varying BSDF* uniform Glass_getBSDF(const uniform PathTraceMaterial* uniform super,
                                          uniform ShadingContext* uniform ctx,
                                          const DifferentialGeometry& dg,
                                          const Ray& ray,
                                          const Medium& currentMedium)
{
  uniform const Glass* uniform self = (uniform const Glass* uniform)super;

  float eta = eq(currentMedium, self->mediumOutside) ? self->mediumOutside.ior*rcp(self->mediumInside.ior)
                                                     : self->mediumInside.ior*rcp(self->mediumOutside.ior);

  varying BSDF* uniform bsdf = Dielectric_create(ctx, dg, eta);
  return bsdf;
}

vec3f Glass_getTransparency(const uniform PathTraceMaterial* uniform material,
                            const DifferentialGeometry& dg,
                            const Ray& ray,
                            const Medium& currentMedium)
{
  const uniform Glass* uniform self = (const uniform Glass* uniform)material;

  float eta = eq(currentMedium, self->mediumOutside) ? self->mediumOutside.ior*rcp(self->mediumInside.ior)
                                                     : self->mediumInside.ior*rcp(self->mediumOutside.ior);

  float cosThetaO = max(-dot(ray.dir, dg.Ns), 0.0f);
  return make_vec3f(1.0f-fresnelDielectric(cosThetaO, eta));
}

void Glass_selectNextMedium(const uniform PathTraceMaterial* uniform super,
                            Medium& currentMedium)
{
  const uniform Glass* uniform self = (const uniform Glass* uniform)super;

  if (eq(currentMedium, self->mediumOutside))
    currentMedium = self->mediumInside;
  else
    currentMedium = self->mediumOutside;
}

///////////////////////////////////////////////////////////////////////////////
// External API

export void PathTracer_Glass_set(
  void* uniform _self,
  const uniform float iorInside,
  const uniform vec3f & attenuationColorInside,
  const uniform float iorOutside,
  const uniform vec3f & attenuationColorOutside,
  const uniform float attenuationDistance)
{
  uniform Glass* uniform self = (uniform Glass* uniform)_self;

  self->mediumInside.ior           = iorInside;
  self->mediumInside.attenuation   = logf(attenuationColorInside) / attenuationDistance;
  self->mediumOutside.ior          = iorOutside;
  self->mediumOutside.attenuation  = logf(attenuationColorOutside) / attenuationDistance;
}

export void* uniform PathTracer_Glass_create()
{
  uniform Glass* uniform self = uniform new uniform Glass;
  PathTraceMaterial_Constructor(&self->super, Glass_getBSDF, 
    Glass_getTransparency, Glass_selectNextMedium);

  return self;
}
