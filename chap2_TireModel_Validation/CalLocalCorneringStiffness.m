function [Car] = CalLocalCorneringStiffness(alpha_local)
    syms AL
m  = 1540;   %mΪ��������,Kg; Sprung mass = 1370
g  = 9.8;
Lf = 1.11;  %a
% Lr = 1.67;  %b��ǰ���־��복�����ĵľ��룬�������в���
L  = 2.78;  %VehiclePara.Lf + VehiclePara.Lr;
mu = 1.0; % 0.55; %����Ħ��������
Fz = 0.5*m*g*Lf/L;
% Calphaf = 91926; %unit: N/rad
Calphar = 75066; %unit: N/rad 
    

Fyf0 = -Calphar * tan(AL) + power(Calphar,2) * tan(AL)* abs(tan(AL))/(3*mu*Fz) - power(Calphar,3)*power(tan(AL),3)/(27*mu*mu*Fz*Fz);

Ca_Jcb = jacobian(Fyf0, AL); 

Tempt = subs(Ca_Jcb,alpha_local);

Car = -eval(Tempt);


    