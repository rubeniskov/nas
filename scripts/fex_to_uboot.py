#!/usr/bin/env python3
"""Convert LCD timing definitions from a sunxi FEX file into U-Boot strings.

Usage:
    ./scripts/fex_to_uboot.py path/to/banana_pro_5lcd.fex --soc a20
"""
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from dataclasses import dataclass
from typing import Dict


LCD_KEYS = {
    "lcd_x",
    "lcd_y",
    "lcd_frm",
    "lcd_dclk_freq",
    "lcd_hv_hspw",
    "lcd_hv_vspw",
    "lcd_hbp",
    "lcd_ht",
    "lcd_vbp",
    "lcd_vt",
}


@dataclass
class LcdTiming:
    x: int
    y: int
    depth: int
    pclk_khz: int
    hs: int
    vs: int
    le: int
    ri: int
    up: int
    lo: int

    def uboot_string(self) -> str:
        return (
            "CONFIG_VIDEO_LCD_MODE=\"x:{x},y:{y},depth:{depth},pclk_khz:{pclk_khz},"
            "le:{le},ri:{ri},up:{up},lo:{lo},hs:{hs},vs:{vs},sync:3,vmode:0\""
        ).format(**self.__dict__)

    def drm_display_mode(self) -> Dict[str, int]:
        hdisplay = self.x
        hsync_start = hdisplay + self.ri
        hsync_end = hsync_start + self.hs
        htotal = hsync_end + self.le

        vdisplay = self.y
        vsync_start = vdisplay + self.lo
        vsync_end = vsync_start + self.vs
        vtotal = vsync_end + self.up

        return {
            "clock": self.pclk_khz,
            "hdisplay": hdisplay,
            "hsync_start": hsync_start,
            "hsync_end": hsync_end,
            "htotal": htotal,
            "vdisplay": vdisplay,
            "vsync_start": vsync_start,
            "vsync_end": vsync_end,
            "vtotal": vtotal,
        }


def parse_fex(path: pathlib.Path) -> Dict[str, str]:
    values: Dict[str, str] = {}
    key_value = re.compile(r"^([^=]+)=(.+)$")

    with path.open() as f:
        for raw_line in f:
            line = raw_line.split(";")[0].strip()
            if not line or line.startswith("["):
                continue
            match = key_value.match(line)
            if not match:
                continue
            key, value = match.group(1).strip(), match.group(2).strip()
            values[key] = value
    return values


def parse_int(values: Dict[str, str], key: str) -> int:
    if key not in values:
        raise KeyError(f"Missing '{key}' in FEX file")
    return int(values[key], 0)


def build_timing(values: Dict[str, str], soc: str) -> LcdTiming:
    missing = LCD_KEYS - values.keys()
    if missing:
        raise KeyError(f"FEX file is missing keys: {', '.join(sorted(missing))}")

    lcd_x = parse_int(values, "lcd_x")
    lcd_y = parse_int(values, "lcd_y")
    lcd_frm = parse_int(values, "lcd_frm")
    lcd_dclk_freq = parse_int(values, "lcd_dclk_freq")
    lcd_hv_hspw = max(1, parse_int(values, "lcd_hv_hspw"))
    lcd_hv_vspw = max(1, parse_int(values, "lcd_hv_vspw"))
    lcd_hbp = parse_int(values, "lcd_hbp")
    lcd_ht = parse_int(values, "lcd_ht")
    lcd_vbp = parse_int(values, "lcd_vbp")
    lcd_vt = parse_int(values, "lcd_vt")

    depth = 24 if lcd_frm == 0 else 18
    pclk_khz = lcd_dclk_freq
    le = max(1, lcd_hbp - lcd_hv_hspw)
    ri = max(1, lcd_ht - lcd_x - lcd_hbp)
    up = max(1, lcd_vbp - lcd_hv_vspw)

    if soc == "sun8i":
        lo = max(1, lcd_vt - lcd_y - lcd_vbp)
    else:
        lo = max(1, lcd_vt // 2 - lcd_y - lcd_vbp)

    return LcdTiming(
        x=lcd_x,
        y=lcd_y,
        depth=depth,
        pclk_khz=pclk_khz,
        hs=lcd_hv_hspw,
        vs=lcd_hv_vspw,
        le=le,
        ri=ri,
        up=up,
        lo=lo,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fex", type=pathlib.Path, help="Path to the FEX file")
    parser.add_argument(
        "--soc",
        choices=["a20", "sun8i"],
        default="a20",
        help="Select formula for the vertical front porch conversion (default: a20)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON with both U-Boot and DRM timings",
    )
    args = parser.parse_args()

    values = parse_fex(args.fex)
    timing = build_timing(values, args.soc)

    if args.json:
        payload = {
            "uboot": timing.uboot_string(),
            "drm_mode": timing.drm_display_mode(),
        }
        print(json.dumps(payload, indent=2))
        return

    print("Generated CONFIG_VIDEO_LCD_MODE:")
    print(timing.uboot_string())
    print()
    print("Panel-simple drm_display_mode suggestion:")
    print(json.dumps(timing.drm_display_mode(), indent=2))


if __name__ == "__main__":
    main()
