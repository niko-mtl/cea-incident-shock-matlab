cea-incident-shock-matlab

MATLAB wrapper for NASA CEA (FCEA2). Builds an incident-shock input deck for equilibrium ionized gas, runs the solver, and writes Initial GAS, Shocked GAS, and mole fractions to Excel. MATLAB + Fortran (legacy FCEA2).

The only file you normally need to change is inp_creator.m. Example files are included so you can see the format. Both are overwritten on every run.

.
├── inp_creator.m      # only file you normally edit
├── FCEA2.exe          # CEA executable
├── thermo.lib
├── trans.lib
├── data_file.inp      # example CEA input  (overwritten each run)
└── data_file.xlsx     # example parsed I/O (overwritten each run)

Requirements: desktop MATLAB (does not work in MATLAB Online). Keep FCEA2.exe, thermo.lib, and trans.lib in the same folder as inp_creator.m. You may call the function from anywhere on the MATLAB path. The executable and libraries must still sit next to the wrapper (or in pwd when it runs).

Call from another MATLAB file with pre-shock temperature, pressure, and incident shock speed:

inp_creator(T, P, u1)    % T [K], P [Pa], u1 [m/s]

inp_creator(300, 2660, 15623.5);

Default pre-shock composition is dry air. These lines are written into the .inp reac block:

fprintf(fid,'  name O2   mole=0.2095\n');
fprintf(fid,'  name N2   mole=0.7808\n');
fprintf(fid,'  name Ar   mole=0.0093\n');
fprintf(fid,'  name CO2  mole=0.0004\n\n');

Swap species / mole fractions for any other mixture. The number of components is not limited. Keep the CEA wording and spacing (name, two spaces, species, mole=). Do not change the token layout on those lines.

Output workbook sheets: InitialGAS (pre-shock state, P converted to Pa), ShockedGAS (post-shock equilibrium state and jump ratios), MoleFractions (equilibrium species, trace cutoff 1e-9).
