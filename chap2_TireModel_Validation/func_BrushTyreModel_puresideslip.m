function [Calphar, Car, Fyf, FyfC] = func_BrushTyreModel_puresideslip(Fz, alpha, mu)
%------------------------------------------------------------------%
% Brush Tire Model by Pacejka
% Using Brush tire model to calcualte Fy 
% Assume slip = 0, mu=1.0
%------------------------------------------------------------------%
%-------Pacejka Tire 175/70 R13(symmetric)----------------------%
%********(1)calculate normal tire load **************%
    m  = 1540; %Ϊ��������,Kg
    g  = 9.8;
    lf = 1.11; %unit:m
    lr = 1.67; %unit:m ǰ���־��복�����ĵľ��룬�������в���
    L  = 2.78;  %unit:m
    Fzf = 0.5*m*g*lr/L; 
    Fzr = 0.5*m*g*lf/L;

    Fz0=4100;                     %nominal (rated) load(>0��,N  %���ֱ�غ�
    Pky1=-12.95;Pky2=1.72;Pky3=0.22; 
    r=0; %0.1*pi/180;                 %camber angle �����
    sr=sin(r);                        %r ������ǣ�sr ��ʾr*
%     Kyaf=Pky1*Fz0*sin(2*atan(Fzf/(Pky2*Fz0)));%ȡlam��Kya��=1 
%     Calphaf=-1*Kyaf*(1-Pky3*sr^2);   %�������Cfa = ByCyDy
    Kyar=Pky1*Fz0*sin(2*atan(Fzr/(Pky2*Fz0)));%ȡlam��Kya��=1 
    Calphar=-1*Kyar*(1-Pky3*sr^2);  %�������Cra = ByCyDy

%********(3)alpha processing **************%
    Alpha_rad = alpha*pi/180;% % alpha  in deg, transform into rad
    tanalpha_rad = tan(Alpha_rad);
%********(4) Using Brush tire model to calcualte Fy  **************%
    % use normal tire load from CarSim
    Fyf0 = -Calphar * tanalpha_rad + power(Calphar,2) * tanalpha_rad* abs(tanalpha_rad)/(3*mu*Fz) - power(Calphar,3)*power(tanalpha_rad,3)/(27*mu*mu*Fz*Fz);
    Fyf = Fyf0;
    if 0 == Alpha_rad
        Car = Calphar;
    else
        Car = Fyf/Alpha_rad;
    end
    
    % use Constant normal tire load 
    FyfC0=-Calphar * tanalpha_rad + power(Calphar,2) * tanalpha_rad* abs(tanalpha_rad)/(3*mu*Fzr) - power(Calphar,3)*power(tanalpha_rad,3)/(27*mu*mu*Fzf*Fzf);
    FyfC = FyfC0;
    
end