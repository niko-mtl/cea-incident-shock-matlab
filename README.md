# cea-incident-shock-matlab
(please open in Code) 

MATLAB wrapper script for NASA CEA (FCEA2) to build the input decks for equilibrium and ionized gases, run the solver, and output the Initial GAS, Shocked GAS, and mole fractions to Excel files. (Matlab + Fortran) 

The only file which you really need to access/modify is inp_creator.m

You need to install fortran alongisde matlab.
You need to drop all these files in the same folder. However, you can call this function from anywhere in your repository. It does not work with web version of matlab 

Then call this function from another matlab file specifying the initial Temperature, Pressure and the shockwave speed 


Initially, the gas composition chosen is air, 

fprintf(fid,'  name O2   mole=0.2095\n');
fprintf(fid,'  name N2   mole=0.7808\n');
fprintf(fid,'  name Ar   mole=0.0093\n');
fprintf(fid,'  name CO2  mole=0.0004\n\n');


you can modify it to any other gas of your choise. 
IMPORTANT: you need to keep the same wording and spacing as in lines 10-13. The number of possible pre-shock gas components isnt limited. 
