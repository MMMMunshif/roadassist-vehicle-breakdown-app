"""Rebuild bundled static weights from the licensed variable font (requires fonttools)."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

source = Path(__file__).resolve().parents[1] / "assets/fonts/PlusJakartaSans-Variable.ttf"
for weight, name in [(200, "ExtraLight"), (300, "Light"), (400, "Regular"), (500, "Medium"), (600, "SemiBold"), (700, "Bold"), (800, "ExtraBold")]:
    font = instantiateVariableFont(TTFont(source), {"wght": weight}, inplace=True)
    font.save(source.with_name(f"PlusJakartaSans-{name}.ttf"))
