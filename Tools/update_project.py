from pathlib import Path
import hashlib,re
root=Path(__file__).resolve().parents[1]
p=root/'Moodium.xcodeproj/project.pbxproj';s=p.read_text()
def uid(t):return hashlib.sha1(t.encode()).hexdigest()[:24].upper()
for f in sorted(list((root/'Moodium').rglob('*.swift')) + list((root/'Moodium').rglob('*.metal'))):
 rel=str(f.relative_to(root))
 if uid(rel) in s:continue
 file=uid(rel);build=uid('build'+rel)
 s=s.replace('objects = {','objects = {\n'+f'{file} = {{ isa = PBXFileReference; lastKnownFileType = {"sourcecode.metal" if f.suffix == ".metal" else "sourcecode.swift"}; path = "{rel}"; sourceTree = SOURCE_ROOT; }};\n{build} = {{ isa = PBXBuildFile; fileRef = {file}; }};',1)
 s=s.replace('isa = PBXGroup; children = (',f'isa = PBXGroup; children = ({file},',1)
 s=s.replace('isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({build},',1)
if uid('resources') not in s:
 file=uid('resources');build=uid('resourcesbuild');phase=uid('resourcesphase')
 s=s.replace('objects = {',f'''objects = {{
{file} = {{ isa = PBXFileReference; lastKnownFileType = folder; path = Moodium/Content; sourceTree = SOURCE_ROOT; }};
{build} = {{ isa = PBXBuildFile; fileRef = {file}; }};
{phase} = {{ isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({build}); runOnlyForDeploymentPostprocessing = 0; }};
''',1)
 s=s.replace('isa = PBXGroup; children = (',f'isa = PBXGroup; children = ({file},',1)
 s=s.replace('buildPhases = (',f'buildPhases = ({phase},',1)
p.write_text(s)
