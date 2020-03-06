(* ::Package:: *)

(* ::Input::Initialization:: *)
0.45;
cubes = Table[
Cuboid[{x-%,y-%,z-%},{x+%,y+%,z+%}],
{x,1,10},{y,1,2},{z,1,3}];
% // Graphics3D


(* ::Input::Initialization:: *)
juliablue=RGBColor[0.251, 0.388, 0.847]
juliagreen=RGBColor[0.22, 0.596, 0.149]
juliapurple=RGBColor[0.584, 0.345, 0.698]
juliared=RGBColor[0.796, 0.235, 0.2]


(* ::Input::Initialization:: *)
block = Graphics3D[
{
(*Cuboid[{1,1,1}/2, {10.5,2.5, 3.5}]},*)
{Specularity[White,50],cubes},

{Darker[Blue],
Arrow[Tube[{{0.5,2.2,4},{10,2.2,4}}]],
Text["range(13, step=2.5, length=10)",{5,3,3.8},{0,-1},{4,1}]
},
{Darker[Purple],
Arrow[Tube[{{10.2,0.0,4}, {10.2,2.1,4}}]],
Text["[:l, :r]",{10.5,1.5,4},{-1,-1},{4,-1}]
},
{Darker[Orange],
Arrow[Tube[{{10.5,0.1,0.8}, {10.5,0.1,3.5}}]],
Text["'\[Alpha]':'\[Gamma]'",{10.5,0,2},{0,1},{1,20}]
}

},
Boxed->False, 
Axes->True,
Ticks->{Range[10], Range[2], Range[3]},
AxesLabel->{":time", ":channel", ":z"},
AxesStyle->Directive[Darker[Gray], Thickness[0.004]],

(*FormatType\[Rule]StandardForm,*)
BaseStyle->{(*FontWeight->"Bold",*)FontSize->12,FontFamily->"Fira Code"},
ImageSize->400,
ViewPoint->{-2,-2,1},

Lighting->{
{"Point",juliared,{-2,3,2}},
{"Point",juliapurple,{11,-4,-1}},
{"Point",juliagreen,{6,5,7}}
},

Epilog->{
Inset["KeyedArray{T,3,...}",{0.3,1},{0,Top}],
(*Inset[Framed["Array{T,3}",Background\[Rule]Opacity[0.5,White]],{0.4,0.4},{0,0}],*)
Inset["NamedDimsArray{L,T,3,...}",{0.7,Bottom},{0,Bottom}]
}
]


(* ::Input:: *)
(*Export[*)
(*FileNameJoin[{NotebookDirectory[], "readmefigure.png"}],*)
(*block,"PNG",ImageResolution->300*)
(*]*)
