function [sys,x0,str,ts] =Main_CurvePathTracking_CVXGEN_Terrain(t,x,u,flag)
%***************************************************************%
% This is a Simulink/Carsim joint simulation solution for safe driving
% envelope control of high speed autonomous vehicle
% Linearized spatial bicycle vehicle dynamic model is applied.
% No successive linearizarion. No two time scale of prediction horizon
% Constant high speed, curve path tracking 
% state vector =[beta,yawrate,e_phi,s,e_y]
% control input = [steer_SW]
% many other parameters are also outputed for comparision.

% Input:
% t�ǲ���ʱ��, x��״̬����, u������(������simulinkģ�������,��CarSim�����),
% flag�Ƿ�������е�״̬��־(�������жϵ�ǰ�ǳ�ʼ���������е�)

% Output:
% sys�������flag�Ĳ�ͬ����ͬ(���潫���flag����sys�ĺ���), 
% x0��״̬�����ĳ�ʼֵ, 
% str�Ǳ�������,����Ϊ��
% ts��һ��1��2������, ts(1)�ǲ�������, ts(2)��ƫ����
%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@gmail.com
% My homepage: https://sites.google.com/site/kailiumiracle/  
%***************************************************************% 
    switch flag,
        case 0 % Initialization %
            [sys,x0,str,ts] = mdlInitializeSizes; % Initialization
        case 2 % Update %
            sys = mdlUpdates(t,x,u); % Update discrete states
        case 3 % Outputs %
            sys = mdlOutputs(t,x,u); % Calculate outputs
        case {1,4,9} % Unused flags
            sys = [];            
        otherwise % Unexpected flags %
            error(['unhandled flag = ',num2str(flag)]); % Error handling
    end %  end of switch    
%  End sfuntmpl

function [sys,x0,str,ts] = mdlInitializeSizes
%==============================================================
% Initialization, flag = 0��mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the S-function.
%==============================================================
sizes = simsizes;%��������ģ������Ľṹ����simsizes������
sizes.NumContStates  = 0;  %ģ������״̬�����ĸ���
sizes.NumDiscStates  = 6;  %ģ����ɢ״̬�����ĸ���,ʵ����û���õ������ֵ��ֻ�����������ʾ��ɢģ��
sizes.NumOutputs     = 15;  %S��������������������������������
sizes.NumInputs      = 38; %S����ģ����������ĸ�������CarSim�������
sizes.DirFeedthrough = 1;  %ģ���Ƿ����ֱ�ӹ�ͨ(direct feedthrough). 1 means there is direct feedthrough.
% ֱ����ͨ��ʾϵͳ�������ɱ����ʱ���Ƿ��ܵ�����Ŀ��ơ�
% a.  ���������mdlOutputs��flag==3��������u�ĺ����������������u��mdlOutputs�б����ʣ������ֱ����ͨ��
% b.  ����һ���䲽��S-Function�ġ���һ������ʱ�䡱������mdlGetTimeOfNextVarHit��flag==4���п��Է�������u��
% ��ȷ����ֱ����ͨ��־��ʮ����Ҫ�ģ���Ϊ��Ӱ��ģ���п��ִ��˳�򣬲����ü���������
sizes.NumSampleTimes = 1;  %ģ��Ĳ���������>=1

sys = simsizes(sizes);    %������󸳸�sys���

x0 = zeros(sizes.NumDiscStates,1);%initial the  state vector�� of no use

str = [];             % ����������Set str to an empty matrix.

ts  = [0.05 0];       % ts=[period, offset].��������sample time=0.05,50ms 

%--Global parameters and initialization
[y, e] = func_RLSFilter_Calpha_f('initial', 0.95, 10, 10);
[y, e] = func_RLSFilter_Calpha_r('initial', 0.95, 10, 10);

    global InitialGapflag; 
    InitialGapflag = 0; % the first few inputs don't count. Gap it.
    
    global VehiclePara; % for SUV
    VehiclePara.m   = 1600;   %mΪ��������,Kg; Sprung mass = 1370
    VehiclePara.g   = 9.81;
    VehiclePara.hCG = 0.65;%m
    VehiclePara.Lf  = 1.12;  % 1.05
    VehiclePara.Lr  = 1.48;  % 1.55
    VehiclePara.L   = 2.6;  %VehiclePara.Lf + VehiclePara.Lr;
    VehiclePara.Tr  = 1.565;  %c,or 1.57. ע����᳤��lc��δȷ��
    VehiclePara.mu  = 0.85; % 0.55; %����Ħ������
    VehiclePara.Iz  = 2059.2;   %IΪ������Z���ת���������������в���  
    VehiclePara.Ix  = 700.7;   %IΪ������Z���ת���������������в���  
    VehiclePara.Radius = 0.387;  % ��̥�����뾶   
    
    global MPCParameters; 
    MPCParameters.Np  = 20;% predictive horizon Assume Np=Nc
    MPCParameters.Ns  = 10; %  Tsplit
    MPCParameters.Ts  = 0.05; % the sample time of near term
    MPCParameters.Tsl = 0.2; % the sample time of long term       
    MPCParameters.Nx  = 6; %the number of state variables
    MPCParameters.Ny  = 2; %the number of output variables      
    MPCParameters.Nu  = 1; %the number of control inputs
    
    global CostWeights; 
    CostWeights.Wephi   = 100; %state vector =[beta,yawrate,e_phi,s,e_y]
    CostWeights.Wey     = 10;
    CostWeights.Ddeltaf = 10;
    CostWeights.deltaf  = 1; % �����ò���
    CostWeights.Wshar   = 500;
    CostWeights.Wshr    = 500;

    
    global Constraints;  
    Constraints.dumax   = 0.1/MPCParameters.Ts;     % Units: rad,0.08rad/s--4.6deg/s  
    Constraints.umax    = 0.4;      % Units: rad appro.23deg
    
    Constraints.arlim   = 6*pi/180; % alpha_lim=6deg~ 0.1047rad
    Constraints.rmax    = 1.0; % rr_max = 1rad/s    
    
    ar_slackMax         = 6*pi/180; % rad
    rmax_slackMax       = 1.0;
    Constraints.Sshmax  = [ar_slackMax; rmax_slackMax];
    
    Constraints.DPhimax = 60*pi/180;  %  ������ƫ��60deg
    Constraints.Dymax   = 1.7; % 3.0;    cross-track-error max 3m

    global WayPoints_IndexPre;
    WayPoints_IndexPre = 1;
    
    global Reftraj;
%     Reftraj = load('WayPoints_Alt3fromFHWA_Overall_Station_Bank.mat');
    Reftraj = load('WayPoints_Alt3fromFHWA_Samples.mat');    
    
    global FeedbackCorrects;
    FeedbackCorrects.StatePred = zeros(6,1);
    FeedbackCorrects.Ctrlopt   = 0;
     
%  End of mdlInitializeSizes

function sys = mdlUpdates(t,x,u)
%==============================================================
% Update the discrete states, flag = 2�� mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%==============================================================
%  ����û���õ�������̣��ں��ڵĳ���ģ�黯ʱ���Լ�������������ܡ�
    sys = x;    
% End of mdlUpdate.

function sys = mdlOutputs(t,x,u)
%==============================================================
% Calculate outputs, flag = 3�� mdlOutputs
% Return the block outputs. 
%==============================================================

%***********Step (1). Parameters Initialization ***************************************%

global InitialGapflag;
global VehiclePara;
global MPCParameters; 
global CostWeights;     
global Constraints;
global WayPoints_IndexPre;
global Reftraj;
global FeedbackCorrects;


Ctrl_SteerSW    = 0;
t_Elapsed       = 0;
PosX            = 0;
PosY            = 0;
PosPsi          = 0;
Vel             = 0;
e_psi           = 0;
e_y             = 0;
fwa_opt         = 0;
Shenvelop_hat   = [0; 0];
r_ssmax         = 0;
YZPM            = 0; 
y_zmp           = 0; 
LTR             = 0; 
Vy              = 0;
alphar          = 0;
Roll_Shad       = 0;
Roll_BaknR      = 0;
Station         = 0;
yawrate         = 0;

% CafHat      = 0;
% CarHat      = 0;
% Fyf         = 0;
% Fyr         = 0;
% Arfa_f      = 0;
% Arfa_r      = 0;
    
if InitialGapflag < 2 %  get rid of the first two inputs,  because no data from CarSim
    InitialGapflag = InitialGapflag + 1;
else % start control
    InitialGapflag = InitialGapflag + 1;
%***********Step (2). State estimation and Location **********************% 
    t_Start = tic; % ��ʼ��ʱ  
    %-----Update State Estimation of measured Vehicle Configuration--------%
    [VehStateMeasured, ParaHAT] = func_StateEstimation(u);   
    PosX        = VehStateMeasured.X;
    PosY        = VehStateMeasured.Y;
    PosPsi      = VehStateMeasured.phi;    
    Vel         = VehStateMeasured.x_dot; 
    Vy          = VehStateMeasured.y_dot; 
    yawrate     = VehStateMeasured.phi_dot; % rad/s
    Ax          = VehStateMeasured.Ax; % x_dot
    Ay          = VehStateMeasured.Ay; % y_dot

%     delta_f     = VehStateMeasured.delta_f;% deg-->rad    
    fwa         = VehStateMeasured.fwa;
    Beta        = VehStateMeasured.beta;%rad
    Roll_Shad   = VehStateMeasured.Roll_Shad;%rad
    Station     = VehStateMeasured.Station;
    Roll        = ParaHAT.Roll;
    Rollrate    = ParaHAT.Rollrate;
    Ay_CG       = ParaHAT.Ay_CG;    
    Ay_Bf_SM    = ParaHAT.Ay_Bf_SM;    
    Fyf         = ParaHAT.Fyf;
    Fyr         = ParaHAT.Fyr;   
    alphaf      = ParaHAT.alphaf;
    alphar      = ParaHAT.alphar;
    
    %-----Estimate Cornering stiffness -------------------%  
    %for front tire
    Arfa_f = (Beta + yawrate*VehiclePara.Lf/Vel - fwa);
    [yf, Calpha_f1] = func_RLSFilter_Calpha_f(Arfa_f, Fyf);
    CafHat = sum(Calpha_f1);
    if CafHat > -30000
        CafHat = -110000;
    end
    %for rear tire 
    Arfa_r = (Beta - yawrate*VehiclePara.Lr/Vel);
    [yr, Calpha_r1] = func_RLSFilter_Calpha_r(Arfa_r, Fyr);
    CarHat = sum(Calpha_r1);
    if CarHat > -30000
        CarHat = -92000;
    end    
    %-----OR use constant Cornering stiffness -------------------%  
    CafHat = -90000;
    CarHat = -90000;
    
    %********Step(3): Given reference trajectory, update vehicle state and bounds *******************% 
    [WPIndex, RefP, RefU, Uaug, Uaug_0, PrjP, Roll_BaknR] = func_RefTraj_LocalPlanning_TwoTimeScales_Spatial_Integrated( MPCParameters,... 
                            VehiclePara,... 
                            WayPoints_IndexPre,... 
                            Reftraj.WayPoints_Collect,... 
                            VehStateMeasured ); % 
      y_zmp =  Uaug_0(2);                 
%     Roll_BaknR =  Uaug_0(1);
%     Uaug_0(1) = Roll_Shad;
                            
    if ( WPIndex <= 0)
       fprintf('Error: WPIndex <= 0 \n');    %����
    else
        Xm = [Vy; yawrate; Rollrate; Roll; PrjP.ey; PrjP.epsi];        
        WayPoints_IndexPre = WPIndex;        
    end

    %****Step(4):  MPC formulation;********************%
%     [StateSpaceModel] = func_RigidbodyDynamicalModel_FOH_Extended(VehiclePara, MPCParameters, Vel, CafHat, CarHat);
    [StateSpaceModel] = func_RigidbodyModel_FOH_Matrix_ROLL(VehiclePara, MPCParameters, Vel, CafHat, CarHat);
    
    Np          = MPCParameters.Np;
    Eymax       = zeros(Np,1);
    Eymin       = zeros(Np,1);     
    LM_right    = -5;
    LM_middle   = 0;
    Yroad_L     = -2.5;
    for i =1:1:Np  % ע��ey�Ǵ����ŵ�, Np = 25
        Eymax(i,1) = (LM_middle - Yroad_L);
        Eymin(i,1) = (LM_right - Yroad_L);             
    end
    [Envelope] = func_SafedrivingEnvelope_SL(VehiclePara, MPCParameters, Constraints, StateSpaceModel, Vel, CarHat,  Eymax, Eymin); 
    
    %--- Weighting Regulation functions
    [Sl, Ql, Rdun, Wshl, dun, dul] = func_CostWeightingRegulation_QuadSlacks(MPCParameters, CostWeights, Constraints);

    %================CVXGEN solver==================================%
    settings.verbose    = 0;       % 0-Silence; 1-display
    settings.max_iters  = 25;    %Limits the total iterations
    
    params.x_0      = Xm;
    params.um       = fwa; % measured front whee angle
%     params.x_0      = Xm - 0.6*(Xm - FeedbackCorrects.StatePred);
%     params.um       = fwa - 0.6*(fwa - FeedbackCorrects.Ctrlopt); 
    
    params.As       = StateSpaceModel.As;
    params.Bs1      = StateSpaceModel.Bs1;
    params.Bs2      = StateSpaceModel.Bs2;
    params.Al       = StateSpaceModel.Al;
    params.Bl11     = StateSpaceModel.Bl11;
    params.Bl12     = StateSpaceModel.Bl12;
    params.Bl21     = StateSpaceModel.Bl21;
    params.Bl22     = StateSpaceModel.Bl22;

    params.tstl     = MPCParameters.Ts/MPCParameters.Tsl;
    params.Ql       = Ql;  
    params.Rdun	    = Rdun;  
    params.Wshl	    = Wshl;      
    
    params.dun      = dun; 
    params.dul      = dul; 
    params.umax     = Constraints.umax;    
    params.Sshmax   = Constraints.Sshmax; 
    
    params.Uaug_0   = Uaug_0;
    params.Uaug     = Uaug;
    
    params.Henv     = Envelope.Henv;
    params.Genv     = Envelope.Genv;
    
    params.Hsh      = Envelope.Hsh;
    params.Psh      = Envelope.Psh;
    params.Gsh      = Envelope.Gsh;
 
    params.Hyzmp    = Envelope.H_yzmp;
    params.Pyzmp1   = Envelope.P_yzmp1;
    params.Pyzmp2   = Envelope.P_yzmp2;
    params.Gyzmp    = 1.0; % 0.7; %��һ�������ص��Լ��    

    [vars, status] = csolve(params, settings);
    if (1 == status.converged) %if optimization succeeded.
        fwa_opt = vars.u_0; 
%         for i=1:1:20
%             S_opt(i)    = vars.x{i}; 
%             U_opt(i)    = vars.u{i}; 
%         end  
    else
        fwa_opt =  vars.u_0;
        fprintf('CVXGEN converged = 0�� InitialGapflag= %d\n', InitialGapflag);                  
    end
    FeedbackCorrects.StatePred = vars.x_1;
    FeedbackCorrects.Ctrlopt   = fwa_opt;    
    %====================================================================%
    Ctrl_SteerSW = 19 * fwa_opt*180/pi; % in deg.    
      
    t_Elapsed = toc( t_Start ); %computation time
    
    %-----------------------------------------%
    e_y            = PrjP.ey;
    e_psi          = PrjP.epsi; 


    Shenvelop_hat  = Envelope.Hsh*Xm + Envelope.Psh*Uaug_0;
    r_ssmax    = Envelope.Gsh(2);

    YZPM = Envelope.H_yzmp*Xm + Envelope.P_yzmp1*fwa_opt + Envelope.P_yzmp2*Uaug_0; % + VehStateMeasured.yawrate_dot*VehiclePara.Iz/(VehiclePara.m*VehiclePara.g);%
    YZPM = 2*YZPM/VehiclePara.Tr;
    
    Fzl = ParaHAT.Fz_l1 + ParaHAT.Fz_l2;
    Fzr = ParaHAT.Fz_r1 + ParaHAT.Fz_r2;
    LTR = (Fzr - Fzl)./(Fzr + Fzl);

    y_zmp  = (Ay_CG)*VehiclePara.hCG/VehiclePara.g + VehiclePara.hCG*(ParaHAT.Roll) - (VehiclePara.Ix)*(ParaHAT.Roll_accel)/(VehiclePara.m*VehiclePara.g);
%     y_zmp  = (Ay_CG)*VehiclePara.hCG/VehiclePara.g + VehiclePara.hCG*(ParaHAT.Roll) - (VehiclePara.Ix)*(ParaHAT.Roll_accel)/(VehiclePara.m*VehiclePara.g); %%%- VehiclePara.hCG*ParaHAT.Roll_accel
% %     y_zmp = ParaHAT.Ay_Bf_SM*ParaHAT.Zcg_SM/VehiclePara.g  + ParaHAT.Zcg_SM.*ParaHAT.Roll - VehiclePara.Ix*(ParaHAT.Roll_accel)/(VehiclePara.m*VehiclePara.g);    
%     y_zmp = 2*y_zmp/VehiclePara.Tr;



     
end % end of if Initialflag < 2 % 

sys = [Ctrl_SteerSW; t_Elapsed; PosX; PosY; PosPsi; Station; Vel; e_psi; e_y; y_zmp; YZPM; LTR; Vy;  alphar; yawrate]; %

%  sys = [Ctrl_SteerSW; CafHat; CarHat; Fyf; Fyr; alphaf; alphar; Arfa_f; Arfa_r];  

% end  %End of mdlOutputs.

%==============================================================
% sub functions
%==============================================================    

%***************************************************************%
% **** State estimation
%***************************************************************%
function [VehStatemeasured, HATParameter] = func_StateEstimation(ModelInput)
%***************************************************************%
% we should do state estimation, but for simplicity we deem that the
% measurements are accurate
% Update the state vector according to the input of the S function,
%           usually do State Estimation from measured Vehicle Configuration
%***************************************************************%  
    %******����ӿ�ת��***%        
    g = 9.81;
    VehStatemeasured.X       = round(100*ModelInput(1))/100;%��λΪm, ����2λС��
    VehStatemeasured.Y       = round(100*ModelInput(2))/100;%��λΪm, ����2λС��    
    VehStatemeasured.phi     = (round(10*ModelInput(3))/10)*pi/180; %����ǣ�Unit��deg-->rad������1λС��    
    VehStatemeasured.x_dot   = ModelInput(4)/3.6; %Unit:km/h-->m/s������1λС��  
    VehStatemeasured.y_dot   = ModelInput(5)/3.6; %Unit:km/h-->m/s������1λС��   
    VehStatemeasured.phi_dot = (round(10*ModelInput(6))/10)*pi/180; %Unit��deg/s-->rad/s������1λС��      
    VehStatemeasured.beta    = (round(10*ModelInput(7))/10)*pi/180;% side slip, Unit:deg-->rad������1λС��    
    VehStatemeasured.delta_f = (round(10*0.5*(ModelInput(8)+ ModelInput(9)))/10)*pi/180; % deg-->rad
    VehStatemeasured.fwa     = VehStatemeasured.delta_f * pi/180;  % deg-->rad
    VehStatemeasured.Steer_SW= ModelInput(10); %deg
    VehStatemeasured.Ax      = g*ModelInput(11);%��λΪm/s^2, ����2λС��
    VehStatemeasured.Ay      = g*ModelInput(12);%��λΪm/s^2, ����2λС��
    VehStatemeasured.yawrate_dot = ModelInput(13); %rad/s^2
    % Here I don't explore the state estimation process, and deem the
    % measured values are accurate!!! 
    HATParameter.alpha_l1   = (round(10*ModelInput(14))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alpha_l2   = (round(10*ModelInput(15))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alpha_r1   = (round(10*ModelInput(16))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alpha_r2   = (round(10*ModelInput(17))/10)*pi/180; % deg-->rad������1λС��     
    HATParameter.alphaf     = (round(10*0.5 * (ModelInput(14)+ ModelInput(16)))/10)*pi/180; % deg-->rad������1λС��   
    HATParameter.alphar     = (round(10*0.5 * (ModelInput(15)+ ModelInput(17)))/10)*pi/180; % deg-->rad������1λС��  
    
    HATParameter.Fz_l1      = round(10*ModelInput(18))/10; % N 
    HATParameter.Fz_l2      = round(10*ModelInput(19))/10; % N 
    HATParameter.Fz_r1      = round(10*ModelInput(20))/10; % N 
    HATParameter.Fz_r2      = round(10*ModelInput(21))/10; % N 
    
    HATParameter.Fy_l1      = round(10*ModelInput(22))/10; % N 
    HATParameter.Fy_l2      = round(10*ModelInput(23))/10; % N 
    HATParameter.Fy_r1      = round(10*ModelInput(24))/10; % N 
    HATParameter.Fy_r2      = round(10*ModelInput(25))/10; % N 
    HATParameter.Fyf        = HATParameter.Fy_l1 + HATParameter.Fy_r1;
    HATParameter.Fyr        = HATParameter.Fy_l2 + HATParameter.Fy_r2;
    
    HATParameter.Fx_L1      = ModelInput(26);
    HATParameter.Fx_L2      = ModelInput(27);
    HATParameter.Fx_R1      = ModelInput(28);
    HATParameter.Fx_R2      = ModelInput(29);
    
%     HATParameter.GearStat    = ModelInput(30);
    VehStatemeasured.Roll_Shad   = ModelInput(30)*pi/180;% deg-->rad 
    HATParameter.Roll        = ModelInput(31)*pi/180;% deg-->rad 
    HATParameter.Rollrate    = ModelInput(32)*pi/180;% deg/s-->rad/s
    HATParameter.Roll_accel  = ModelInput(33); % rad/s^2
    HATParameter.Z0          = ModelInput(34); %m
    VehStatemeasured.Station     = ModelInput(35); %m
    HATParameter.Zcg_TM      = ModelInput(35); %m
    HATParameter.Zcg_SM      = ModelInput(36); %m
    HATParameter.Ay_CG       = ModelInput(37)*g; %m/s^2
    HATParameter.Ay_Bf_SM    = ModelInput(38)*g; %m/s^2
    
% end % end of func_StateEstimation


