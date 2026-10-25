"""
MCLPU-100 (Multi Computer Large Processing Unit)
Interactive & Dynamic Hardware Physics Simulator v2.0
License: Apache 2.0
"""

import random
import time

print("==========================================================")
print("   MCLPU-100: LIVE INTERACTIVE HARDWARE SIMULATOR v2.0    ")
print("==========================================================\n")

# ---------------------------------------------------------
# TEST 1: Interactive 1T-1M In-Memory Matrix Engine
# ---------------------------------------------------------
print("[1] LIVE 1T-1M ANALOG MATRIX CALCULATOR")
print("Enter 4 input voltages separated by spaces (e.g., 0.5 1.2 0.8 0.3)")
user_in = input(" -> Or press ENTER to generate random live voltages: ").strip()

if user_in:
    # Uses the exact numbers YOU typed in!
    voltages = [float(x) for x in user_in.split()[:4]]
    while len(voltages) < 4:
        voltages.append(0.5)
else:
    # Un-seeded! Brand new random voltages every single millisecond you run it
    voltages = [round(random.uniform(0.1, 1.2), 2) for _ in range(4)]

# Generate a live 4x4 memory crossbar of conductance weights (in micro-Siemens)
weights = [[round(random.uniform(10.0, 50.0), 1) for _ in range(4)] for _ in range(4)]

print(f"\n -> Active Input Voltages (V) : {voltages}")
print(" -> Memory Tier Conductance Grid (G in uS):")
for row in weights:
    print("    ", row)

# REAL CALCULATION: Kirchhoff's Current Law (I = sum of V * G down each column)
start_time = time.perf_counter_ns()
output_currents = []
for col in range(4):
    col_current = 0.0
    for row in range(4):
        col_current += voltages[row] * weights[row][col]
    output_currents.append(round(col_current, 2))
end_time = time.perf_counter_ns()

print(f"\n -> CALCULATED OUTPUT CURRENTS (uA): {output_currents}")
print(f" -> Proof for Column 1: ({voltages[0]}*{weights[0][0]}) + ({voltages[1]}*{weights[1][0]}) + ({voltages[2]}*{weights[2][0]}) + ({voltages[3]}*{weights[3][0]}) = {output_currents[0]} uA")
print(f" -> Host Simulation Time: {end_time - start_time} nanoseconds\n")


# ---------------------------------------------------------
# TEST 2: Live 3D (X, Y, Z) Heat & Signal Diffusion Loop
# ---------------------------------------------------------
print("----------------------------------------------------------")
print("[2] LIVE 3D VOLUMETRIC VIA SIGNAL PROPAGATION (5 CYCLES)")

# 3x3x3 Cube of 1T-1M nodes starting at 0.0
cube = [[[0.0 for _ in range(3)] for _ in range(3)] for _ in range(3)]

# Ask user how much energy to inject into the center of the 3D chip
pulse_in = input(" -> Enter signal energy to inject at Center Node (e.g., 500): ").strip()
pulse = float(pulse_in) if pulse_in else round(random.uniform(100.0, 1000.0), 1)
cube[1][1][1] = pulse

print(f" -> Injected {pulse} units at Center (Z=1, Y=1, X=1). Watching it spread across tiers:")

for cycle in range(1, 6):
    # Calculate real 3D neighbor transfer across X, Y, Z vias
    center = cube[1][1][1]
    z_up   = cube[2][1][1]
    z_down = cube[0][1][1]
    
    # Energy flows from center node into vertical & horizontal neighbors
    transfer = center * 0.12
    cube[1][1][1] -= transfer * 6
    cube[2][1][1] += transfer  # Tier Above
    cube[0][1][1] += transfer  # Tier Below
    cube[1][2][1] += transfer  # North
    cube[1][0][1] += transfer  # South
    cube[1][1][2] += transfer  # East
    cube[1][1][0] += transfer  # West
    
    print(f"    Cycle {cycle}: Center={cube[1][1][1]:.2f} | Tier Above (Z+1)={cube[2][1][1]:.2f} | Tier Below (Z-1)={cube[0][1][1]:.2f}")


# ---------------------------------------------------------
# TEST 3: Live Thermal Stress Test (Try to Melt the Chip!)
# ---------------------------------------------------------
print("\n----------------------------------------------------------")
print("[3] DIAMOND COOLING STRESS TEST (TRY TO MELT THE CHIP)")
power_in = input(" -> Enter Chip Power Load in Watts/cm^2 (e.g., 1000 or 25000): ").strip()
power_w_cm2 = float(power_in) if power_in else random.randint(500, 5000)

heat_flux_w_m2 = power_w_cm2 * 10000.0  # Convert W/cm^2 to W/m^2
stack_thickness_m = 0.000002            # 100 tiers = 2 micrometers

# Physics Formula: Delta_T = (Heat_Flux * Thickness) / Thermal_Conductivity
silicon_rise = (heat_flux_w_m2 * stack_thickness_m) / 150.0   # Silicon = 150 W/mK
diamond_rise = (heat_flux_w_m2 * stack_thickness_m) / 2000.0  # Diamond = 2000 W/mK

base_ambient_temp = 35.0 # 35°C starting room/coolant temperature

print(f"\n -> Testing at {power_w_cm2:,.1f} Watts/cm^2:")
print(f" -> Standard Silicon Chip Internal Temp : {base_ambient_temp + silicon_rise:.3f} °C (+{silicon_rise:.4f} °C rise)")
print(f" -> MCLPU Diamond Chip Internal Temp    : {base_ambient_temp + diamond_rise:.3f} °C (+{diamond_rise:.4f} °C rise)")

if (base_ambient_temp + diamond_rise) > 105.0:
    print(" -> [WARNING]: EXTREME OVERLOAD! Even Diamond reached thermal throttling (>105°C)!")
else:
    print(" -> [PASS]: Diamond interlayer kept the 100-tier stack cool and operational!")
print("==========================================================")
