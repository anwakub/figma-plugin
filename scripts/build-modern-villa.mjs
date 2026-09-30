import { bridge } from './roblox-bridge-client.mjs';

// Reference-inspired two-storey villa. Front faces -Z; offset from the earlier demo.
const model = 'ModernLuxuryVilla';
const origin = 145;
const palette = { white:[236,234,225], stone:[98,103,101], dark:[36,43,43], wood:[147,107,68], floor:[196,185,163], glass:[165,199,198], grass:[64,93,60], hedge:[38,70,44], water:[49,135,146], brass:[163,133,79] };
const parts = [];
const counts = {};
function part(group, name, xyz, size, color='white', extra={}) {
  counts[group] = (counts[group] ?? 0) + 1;
  parts.push({group,name:`${group}_${String(counts[group]).padStart(3,'0')}_${name}`,position:[origin+xyz[0],xyz[1],xyz[2]],size,color:palette[color]??color,...extra});
}
function box(name, pos, size, color='white') {part('Structure',name,pos,size,color);}
function wood(name,pos,size) {part('Timber',name,pos,size,'wood');}
function glass(name,pos,size) {part('Glazing',name,pos,size,'glass',{transparency:0.68});}
function pane(x,y,z,w,h,axis='front') {
  const side=axis==='side';
  glass('Glass', [x,y,z], side?[0.16,h,w]:[w,h,0.16]);
  for(const sign of [-1,1]) {
    part('Frames','Mullion',[x+(side?0:sign*w/2),y,z+(side?sign*w/2:0)],side?[0.28,h,0.22]:[0.22,h,0.28],'dark');
    part('Frames','Rail',[x,y+sign*h/2,z],side?[0.28,0.22,w]:[w,0.22,0.28],'dark');
  }
}
// Continuous foundation and first-floor slabs, with a recessed upper entrance wing.
box('Plinth',[0,1.25,3],[100,2.5,47],'stone');
box('GroundFloor',[0,2.8,3],[96,0.6,43],'floor');
box('UpperSlab',[-1,17.1,2],[100,1.4,46]);
box('RearWall',[0,17,24],[96,29,1.2],'stone');
box('LeftEnd',[-47.5,17,6],[1,29,35],'stone');
box('RightEnd',[47.5,16,8],[1,27,32],'stone');
box('LeftFeature',[-39,10,-19],[17,14,1.2],'stone');
box('LeftFeatureUpper',[-39,24.5,-18],[17,13.4,1.2],'stone');
box('UpperCentralRear',[4,24.2,-5],[1.2,13,18],'stone');
box('StairDivider',[-13,9,14],[1,12,19],'white');
box('BedroomDivider',[9,24.3,11],[0.8,13,25],'white');
box('GroundLintel',[1,16,-19],[98,1,1]);
box('LeftRoof',[-31,32.2,0],[38,1.3,49]);
box('LinkRoof',[-7,30,5],[12,1.1,37],'stone');
box('CenterRoof',[13,32,0],[29,1.2,45]);
box('RightRoof',[38,30.4,3],[25,1.2,42]);
// White projecting rectangular portal, matching the reference's deep horizontal frames.
for (const [x,w,z,top] of [[-31,38,-24,32.2],[13,29,-22,32],[38,25,-18,30.4]]) {
  box('PortalTop',[x,top,z],[w,1.5,2]);
  box('PortalBase',[x,18,z],[w,1.25,2]);
  for(const side of [-1,1]) box('PortalSide',[x+side*(w/2-0.65),(top+18)/2,z],[1.3,top-18,2]);
  wood('Soffit',[x,top-0.82,z+5],[w-2,0.22,10]);
  for(let xx=x-w/2+2;xx<x+w/2-1;xx+=1.2) part('Timber','SoffitSeam',[xx,top-0.95,z+5],[0.05,0.07,9.8],[107,77,49]);
}
// Full-height glazing with visible mullions, upper terrace and lower living rooms.
for(const x of [-28,-21,-14,-7,0,7,14,21,28,35,42]) pane(x,9.5,-18.7,7,12.7);
for(const x of [-27,-20,-13]) pane(x,24.7,-16,7,12);
for(const x of [3.5,10.5,17.5,24.5]) pane(x,24.5,-10,7,12);
for(const x of [32,39,46]) pane(x,23.8,-9,7,11);
for(const z of [-11,-4,3,10,17]) {pane(-48,9.5,z,7,12.7,'side'); pane(48,9.5,z,7,12.7,'side');}
// Transparent balcony along the front, metal top rail and minimalist posts.
for(let x=-45;x<48;x+=6) {
  glass('Balustrade',[x,20,-23],[5.9,3.4,0.14]);
  part('Frames','BalconyPost',[x-3,20,-23],[0.13,3.8,0.16],'dark');
}
part('Frames','BalconyHandrail',[0,21.8,-23],[98,0.16,0.22],'dark');
for(const x of [-48.5,48.5]) {glass('BalconyReturn',[x,20,-19],[0.14,3.4,8]);part('Frames','ReturnRail',[x,21.8,-19],[0.22,0.16,8],'dark');}
// Ground portico columns and warm timber facade accents.
for(const x of [-29,-10,9,28,46]) {wood('PorticoColumn',[x,9.3,-22],[0.85,13,0.85]);box('ColumnFoot',[x,3,-22],[1.3,0.4,1.3],'stone');}
wood('PorticoBeam',[8,16.2,-22],[79,0.7,0.9]);
for(let x=-46;x<-32;x+=0.8) wood('CladdingSlat',[x,24.8,-18.8],[0.32,12.3,0.3]);
for(let x=1;x<28;x+=0.9) wood('CladdingSlat',[x,24.7,-8.8],[0.3,12.4,0.32]);
// Interiors visible through the glazing.
function furniture(name,xyz,size,color='floor'){part('Interior',name,xyz,size,color);}
furniture('LivingRug',[-22,3.2,-5],[25,0.12,16],[149,145,134]);
furniture('SofaBase',[-22,4.1,0],[17,1.8,4.5],[187,182,168]);
furniture('SofaBack',[-22,5.5,1.7],[17,2.5,1],[220,216,204]);
for(const x of [-29,-25.5,-22,-18.5,-15]) furniture('SofaCushion',[x,5.1,-0.5],[3.2,0.5,3],[236,227,206]);
for(const x of [-30,-14]) furniture('SofaArm',[x,5.1,0],[1,2.2,4.5],[208,200,184]);
furniture('CoffeeTable',[-22,4.6,-7],[9,0.4,4.5],'wood');
for(const x of [-25,-19]) furniture('CoffeeLeg',[x,3.8,-7],[0.5,1.2,3],'dark');
furniture('BookA',[-24,4.95,-7],[2.2,0.24,1.5],'dark');
furniture('BookB',[-23.8,5.18,-7],[2,0.2,1.4],[172,121,88]);
furniture('TVWall',[-22,9,20],[22,10,0.5],'wood');
furniture('Screen',[-22,10,19.6],[12,6,0.22],[19,24,25]);
furniture('MediaCabinet',[-22,4,18.5],[23,2,2.5],'stone');
furniture('DiningTop',[21,6,2],[17,0.6,6],'wood');
for(const x of [15,27]) furniture('DiningBase',[x,4.5,2],[1.2,2.7,3.5],'dark');
for(const x of [15,21,27]) for(const z of [-2.5,6.5]) {furniture('DiningSeat',[x,4.8,z],[3.5,0.6,3.3],[179,169,148]);furniture('DiningBack',[x,6,z+(z<0?-1.3:1.3)],[3.5,2.4,0.5],[193,183,161]);furniture('ChairLeg',[x,3.8,z],[2.5,1.5,2.2],'dark');}
furniture('KitchenIsland',[24,5.5,16],[20,4.7,5],'stone');
furniture('IslandStoneTop',[24,8,16],[21,0.45,6],[224,220,207]);
for(let i=0;i<19;i++) furniture('Stair',[-6,3.25+i*0.72,21-i*1.25],[8,0.45,1.3],'wood');
furniture('BedBase',[-30,19.5,7],[14,2,17],'wood');
furniture('Mattress',[-30,20.8,7],[13.5,1,16],[235,230,219]);
furniture('BedThrow',[-30,21.4,2.5],[13.6,0.25,6],[115,135,128]);
furniture('Headboard',[-30,22.3,15],[16,6,0.6],[163,149,131]);
for(const x of [-33.5,-26.5]) furniture('Pillow',[x,21.6,12],[5.5,0.7,3],[249,244,232]);
furniture('UpperRug',[18,18.5,2],[18,0.1,14],[176,170,153]);
furniture('UpperSofa',[18,20,7],[14,2.8,4],[199,194,177]);
furniture('UpperBack',[18,21.8,8.5],[14,2.5,0.7],[215,210,193]);
furniture('UpperCoffee',[18,20,-0.5],[8,0.4,4],'wood');
// Terraced pool courtyard with a real recessed basin; water is a translucent Part.
part('Site','Lawn',[0,0.2,-13],[136,0.6,115],'grass');
part('Pool','Terrace',[0,2,-25.5],[103,1.2,10],'floor');
part('Pool','BasinFloor',[8,0.6,-42],[67,0.4,17],'water');
for(const z of [-51,-33]) part('Pool','Coping',[8,2,z],[70,0.6,1.5],'floor');
for(const x of [-26.25,42.25]) part('Pool','Coping',[x,2,-42],[1.5,0.6,19],'floor');
for(const z of [-50.5,-33.5]) part('Pool','BasinWall',[8,1.1,z],[67,1.7,0.3],[76,103,109]);
for(const x of [-25.5,41.5]) part('Pool','BasinWall',[x,1.1,-42],[0.3,1.7,17],[76,103,109]);
part('Pool','Water',[8,1.7,-42],[66.6,0.12,16.6],'water',{transparency:0.3,canCollide:false});
part('Pool','LeftDeck',[-38,1.5,-42],[21,1,24],'wood');
part('Pool','RightDeck',[49,1.5,-41],[12,1,26],'floor');
for(let z=-53;z<-31;z+=1.1) part('Timber','DeckSeam',[-38,2.02,z],[20.5,0.02,0.04],[94,70,48]);
for(const x of [-16,-7,2,11]) {
  part('Pool','LoungerFrame',[x,3,-29],[5.5,0.45,8],'dark');
  part('Pool','LoungerCushion',[x,3.4,-29],[5.2,0.45,7.5],[224,218,197]);
  part('Pool','LoungerBack',[x,4,-26.3],[5.2,1.1,2.2],[224,218,197]);
}
// Deliberate landscape bands, pavers, clipped hedges, canopy trees and planters.
for(let z=-65;z<-30;z+=6) part('Garden','SteppingStone',[-46,0.8,z],[10,0.4,4.2],[141,148,140]);
for(let z=-62;z<-29;z+=6) part('Garden','SteppingStone',[53,0.8,z],[8,0.4,4.2],[141,148,140]);
for(const x of [-61,62]) part('Garden','BoundaryHedge',[x,2.5,-12],[3.5,4.5,104],'hedge');
part('Garden','FrontHedge',[-4,1.7,-62],[76,2.6,3],'hedge');
part('Garden','PoolHedge',[8,1.4,-54],[67,1.8,2],'hedge');
for(const [x,z] of [[-56,-24],[56,-20],[-56,15],[58,17],[-34,-58],[35,-59]]) {
  part('Trees','Trunk',[x,6,z],[1.2,11,1.2],[104,83,56]);
  for(const [dx,dy,dz,s] of [[0,14,0,10],[-3,12,1,8],[3,12,-1,8],[0,16,0,7]]) part('Trees','Canopy',[x+dx,dy,z+dz],[s,s*0.78,s],[48+Math.round(dy),80+Math.round(dy),48]);
}
for(const [x,z,y] of [[-28,-22,3],[43,-22,3],[-6,-20,18],[25,-18,18],[43,-16,18],[-42,-49,2]]) {
  part('Plants','Planter',[x,y+1.3,z],[2.8,2.6,2.8],[143,142,127]);
  for(const [dx,dy,dz] of [[0,4,0],[-0.8,3.6,0.4],[0.8,3.7,-0.3]]) part('Plants','Foliage',[x+dx,y+dy,z+dz],[2.3,2.5,2],[51,83,48]);
}
for(let i=0;i<28;i++) {const x=-31+i*2.4;part('Plants','LowShrub',[x,1.1,-59],[2.9,1.8,2.4],[48+(i%3)*8,79+(i%4)*6,48]);}
for(const x of [-55,-36,-17,2,21,40,59]) {
  part('Lights','Bollard',[x,1.8,-57],[0.65,2.7,0.65],'dark');
  part('Lights','Glow',[x,3.1,-57],[0.76,0.55,0.76],[255,216,152]);
}
for(const [x,y,z] of [[-43,31,-20],[-28,31,-20],[-14,31,-20],[2,30.8,-18],[13,30.8,-18],[24,30.8,-18],[33,29.3,-14],[44,29.3,-14],[-25,16,-21],[-8,16,-21],[9,16,-21],[26,16,-21],[43,16,-21]]) part('Lights','Downlight',[x,y,z],[0.5,0.14,0.5],[255,221,164]);
for(const [x,z] of [[-46,-19.9],[-32,-19.9],[47,-19.9]]) {
  part('Lights','Sconce',[x,11,z],[0.7,2.3,0.5],'dark');
  part('Lights','SconceGlow',[x,10.3,z-0.25],[0.55,0.5,0.3],[255,210,145]);
}

// Generate a self-contained Studio command as a reusable artifact, without a relay.
if (process.argv.includes('--export-lua')) {
  const {readFile,writeFile,mkdir}=await import('node:fs/promises');
  const luaString=value=>JSON.stringify(value);
  const lines=[
    '-- Paste into the Roblox Studio Command Bar in edit mode. Creates one complete villa.',
    '-- Existing ModernLuxuryVilla is preserved; choose a new place to build another copy.',
    'assert(not workspace:FindFirstChild("ModernLuxuryVilla"), "ModernLuxuryVilla already exists")',
    'game:GetService("ChangeHistoryService"):SetWaypoint("Before creating ModernLuxuryVilla")',
    'local villa=Instance.new("Model"); villa.Name="ModernLuxuryVilla"; villa.Parent=workspace',
    'local groups={}',
  ];
  for(const group of Object.keys(counts)) lines.push(`groups[${luaString(group)}]=Instance.new("Model"); groups[${luaString(group)}].Name=${luaString(group)}; groups[${luaString(group)}].Parent=villa`);
  lines.push('local function add(group,name,position,size,color,transparency,collide) local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.Position=position; p.Size=size; p.Color=color; p.Transparency=transparency; p.CanCollide=collide; p.Parent=groups[group] end');
  for(const p of parts) lines.push(`add(${luaString(p.group)},${luaString(p.name)},Vector3.new(${p.position.join(',')}),Vector3.new(${p.size.join(',')}),Color3.fromRGB(${p.color.join(',')}),${p.transparency??0},${p.canCollide!==false})`);
  lines.push(await readFile(new URL('./finish-modern-villa.luau',import.meta.url),'utf8'));
  await mkdir(new URL('../artifacts/',import.meta.url),{recursive:true});
  await writeFile(new URL('../artifacts/ModernLuxuryVilla.luau',import.meta.url),lines.join('\n'),'utf8');
  console.log(`Exported artifacts/ModernLuxuryVilla.luau with ${parts.length} parts plus finishing pass.`);
  process.exit(0);
}

const client = await bridge();
try {
  const info=await client.send('get_place_info');
  console.log('Connected: '+info.placeName);
  console.log(JSON.stringify(await client.send('get_selection')));
  const existing=await client.send('find_instances',{name:model,className:'Model',maxResults:20});
  const exists=existing.instances.some(x=>x.path===`Workspace/${model}`);
  if(exists && !process.argv.includes('--resume')) throw new Error('Model already exists; use --resume to inspect and fill missing parts.');
  if(!exists) {
    await client.send('create_model',{name:model});
    for(const group of Object.keys(counts)) await client.send('create_model',{name:group,parentPath:`Workspace/${model}`});
  }
  const present=new Set();
  if(exists) for(const group of Object.keys(counts)) {
    const found=await client.send('find_instances',{name:`${group}_`,className:'Part',maxResults:200});
    for(const item of found.instances) if(item.path.startsWith(`Workspace/${model}/`)) present.add(item.path);
  }
  let done=0;
  for(const item of parts) {
    const {group,transparency,canCollide,...params}=item;
    if(present.has(`Workspace/${model}/${group}/${item.name}`)) {done++;continue;}
    const created=await client.send('create_part',{...params,parentPath:`Workspace/${model}/${group}`,anchored:true});
    if(transparency!==undefined || canCollide!==undefined) await client.send('set_instance_properties',{path:created.path,transparency,canCollide});
    if(++done%60===0) console.log(`Created ${done}/${parts.length}`);
    await new Promise(resolve=>setTimeout(resolve,450));
  }
  const verified={};
  for(const [group,count] of Object.entries(counts)) {
    const found=await client.send('find_instances',{name:`${group}_`,className:'Part',maxResults:200});
    verified[group]=found.instances.filter(x=>x.path.startsWith(`Workspace/${model}/`)).length;
    if(verified[group]!==count) throw new Error(`Count mismatch for ${group}: ${verified[group]} expected ${count}`);
  }
  console.log(JSON.stringify({model,parts:parts.length,verified,center:[origin,15,-12]}));
} finally {client.close();}
