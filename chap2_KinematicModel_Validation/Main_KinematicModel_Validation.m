function [sys,x0,str,ts] =Main_KinematicModel_Validation(t,x,u,flag)
%***************************************************************%
% ��2.1���������ĳ����˶�ģ�͵ķ�����֤
%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@bit.edu.cn
% My github: https://github.com/leoking99-BIT
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
% end %  end sfuntmpl

%==============================================================
% Initialization, flag = 0��mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the S-function.
%==============================================================
function [sys,x0,str,ts] = mdlInitializeSizes
%***************************************************************%
% Call simsizes for a sizes structure, fill it in, and convert it 
% to a sizes array.
%***************************************************************% 
sizes = simsizes;%��������ģ������Ľṹ����simsizes������
sizes.NumContStates  = 0;  %ģ������״̬�����ĸ���
sizes.NumDiscStates  = 5;  %ģ����ɢ״̬�����ĸ���,ʵ���ϱ�app û���õ������ֵ��ֻ�����������ʾ��ɢģ��
sizes.NumOutputs     = 10;  %S��������������������������������
sizes.NumInputs      = 10; %S����ģ����������ĸ�������CarSim�������
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
  
global InitialGapflag; 
    InitialGapflag = 0; % Ignore the first few inputs from CarSim
global Previous_States; % store the previous state vector 
    Previous_States.X_pred = 0.0; 
    Previous_States.Y_pred = 0.0; 
    Previous_States.Yaw_pred = 0.0;

% RLS initialization
[y, c] = func_SteerRatio_Estimation_RLS('initial', 0.95, 1, 10);
[y, e] = func_SteerRatio_Estimation_RLS_array('initial', 0.95, 10, 10);
%  End of mdlInitializeSizes

%==============================================================
% Update the discrete states, flag = 2�� mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%==============================================================
function sys = mdlUpdates(t,x,u)
%  Ŀǰû���õ�������̣��ں��ڵĳ���ģ�黯ʱ���Լ�������������ܡ�
    sys = x;
% end     %End of mdlUpdate.

%==============================================================
% Calculate outputs, flag = 3�� mdlOutputs
% Return the block outputs. 
%==============================================================
function sys = mdlOutputs(t,x,u)
%t�ǲ���ʱ��, x��״̬����, u������(������simulinkģ�������)
global InitialGapflag; 
global Previous_States;
lfr = 2.78;
Ts = 0.05;
Steer_ratio = 1;

    % ��ȡCarSim���뵽Simulink������
    x_L2 = u(1); %�����x����
    x_R2 = u(2); %�Һ���x����
    y_L2 = u(3); %�����y����
    y_R2 = u(4); %�Һ���y����   
    Yaw  = u(5)*pi/180;%�����Unit��deg-->rad
    Steer_SW = u(6); %�����̽Ƕ�
    Steer_L1 = u(7); %��ǰ��ƫ��
    Steer_R1 = u(8); %��ǰ��ƫ��
    Vx_L2 = u(9);  %����������ٶȣ�Unit:km/h
    Vx_R2 = u(10); %�Һ��������ٶȣ�Unit:km/h
    
    Car_X = 0.5*(x_L2 + x_R2);%��������X���꣬Unit:m
    Car_Y = 0.5*(y_L2 + y_R2);%��������Y���꣬Unit:m
    Vx_km_h = 0.5*(Vx_L2 + Vx_R2);%�������Ĵ������ٶ�,Unit��km/h
    Steer_deg = 0.5*(Steer_L1 + Steer_R1);%��Чǰ��ƫ�ǣ�Unit��deg
    
    Vx_m_s  = Vx_km_h/3.6;%%�������Ĵ������ٶ� in (m/s),Unit��m/s    
    Steer_rad = Steer_deg*pi/180;%��Чǰ��ƫ��in (rad)��Unit��degs-->rad;

if (InitialGapflag < 3) %  Ignore the first few inputs
    InitialGapflag = InitialGapflag + 1;
    X_pred = Car_X; 
    Y_pred = Car_Y; 
    Yaw_pred = Yaw;
    Previous_States.X_pred = Car_X; 
    Previous_States.Y_pred = Car_Y; 
    Previous_States.Yaw_pred = Yaw;
else % start control
    %-----I. Update predicted states using differential equation--------%
%     Updated_state = func_UpdateState_dsolve_2_7(Previous_States, lfr, Vx_m_s, Steer_rad, Ts);

    %-----II. Update predicted states using RK4-------%
    
    %-----III. Update predicted states using Euler Method------%
    Updated_state = func_UpdateState_EulerM_2_7(Previous_States, lfr, Vx_m_s, Steer_rad, Ts);
    
    X_pred = Updated_state.X_pred; 
    Y_pred = Updated_state.Y_pred; 
    Yaw_pred = Updated_state.Yaw_pred;
    
    Previous_States.X_pred = X_pred; 
    Previous_States.Y_pred = Y_pred; 
    Previous_States.Yaw_pred = Yaw_pred;

    %-----Estimate Steer_ratio-----%  
%     [Steer_SW_hat, Steer_ratio, Rinv_f] = func_SteerRatio_Estimation_RLS(Steer_deg, Steer_SW);
%     Hat_err = Steer_SW_hat - Steer_SW;
    [Steer_SW_hat, Steer_ratio_vector] = func_SteerRatio_Estimation_RLS_array(Steer_deg, Steer_SW);
    Steer_ratio =sum(Steer_ratio_vector);
 
 
end % End of if (Initialflag < 3) % 

    
    sys = [Car_X; Car_Y; Yaw; X_pred; Y_pred; Yaw_pred; Vx_m_s; Steer_rad; Steer_SW; Steer_ratio];  
       
% end  %End of mdlOutputs.

