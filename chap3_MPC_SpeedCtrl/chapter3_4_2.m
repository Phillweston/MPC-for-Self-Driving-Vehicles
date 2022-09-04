function [sys,x0,str,ts] =MY_MPCController3(t,x,u,flag)
%***************************************************************% 
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
%  End sfuntmpl

%==============================================================
% Initialization, flag = 0��mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the S-function.
%==============================================================
function [sys,x0,str,ts] = mdlInitializeSizes
sizes = simsizes;%��������ģ������Ľṹ����simsizes������
sizes.NumContStates  = 0;  %ģ������״̬�����ĸ���
sizes.NumDiscStates  = 2;  %ģ����ɢ״̬�����ĸ���,ʵ����û���õ������ֵ��ֻ�����������ʾ��ɢģ��
sizes.NumOutputs     = 6;  %S��������������������������������
sizes.NumInputs      = 2; %S����ģ����������ĸ�������CarSim�������
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
global InitialGapflag; 
    InitialGapflag = 0; % the first few inputs don't count. Gap it.
global MPCParameters; 
    MPCParameters.Np      = 30;% predictive horizon
    MPCParameters.Nc      = 30;% control horizon
    MPCParameters.Nx      = 2; %number of state variables
    MPCParameters.Nu      = 1; %number of control inputs
    MPCParameters.Ny      = 1; %number of output variables  
    MPCParameters.Ts      = 0.05; %Set the sample time
    MPCParameters.Q       = 100; % cost weight factor 
    MPCParameters.R       = 1; % cost weight factor 
    MPCParameters.S       = 1; % cost weight factor 
    MPCParameters.qp_solver = 2; %0: default, quadprog; 1:qpOASES; 2:CVXGEN
    MPCParameters.refspeedT = 0; %0: default, step speed profile; 
                                 %1:sine-wave speed profile
    MPCParameters.umin      = -5.0;  % the min of deceleration
    MPCParameters.umax      = 3.5;  % the max of acceleration
    MPCParameters.dumin     = -5.0; % minimum limits of jerk
    MPCParameters.dumax     = 5.0; % maximum limits of jerk
global WarmStart;
    WarmStart = zeros(MPCParameters.Np,1);
%  End of mdlInitializeSizes

%==============================================================
% Update the discrete states, flag = 2�� mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%==============================================================
function sys = mdlUpdates(t,x,u)
%  ����û���õ�������̣��ں��ڵĳ���ģ�黯ʱ���Լ�������������ܡ�
    sys = x;    
% End of mdlUpdate.

%==============================================================
% Calculate outputs, flag = 3�� mdlOutputs
% Return the block outputs. 
%==============================================================
function sys = mdlOutputs(t,x,u)

global InitialGapflag;
global MPCParameters;
global WarmStart;
Vx    = 0;
a_x   = 0;
a_des = 0;

t_Start = tic; % ��ʼ��ʱ 
if InitialGapflag < 2 %  get rid of the first two inputs
    InitialGapflag = InitialGapflag + 1;%
else
    InitialGapflag = InitialGapflag + 1;
    %***********Step (1). Update vehicle states *************************% 
    Vx    = u(1)/3.6;  %���������ٶȣ���λ��km/h-->m/s
    a_x   = u(2)*9.8;  %����������ٶȣ���λ��g's-->m/s2 
    kesi = [Vx;  a_x]; %���³���״̬����
    
    %********Step(2): Generate reference speed profile *******************%
    switch MPCParameters.refspeedT,
        case 0 % default, step speed profile
            %----�趨����ʽ�������ٶ�����----------------------%
            SpeedProfile = func_ConstantSpeed(InitialGapflag, MPCParameters);
        case 1 % sine-wave speed profile
            %----����sine wave��ʽ �������ٶ�����--------------%
            SpeedProfile = func_SineSpeed(InitialGapflag,MPCParameters);
        otherwise % Unexpected flags %
            error(['unexpected speed-profile:',num2str(MPCParameters.refspeedT)]); % Error handling
    end %  end of switch 
    
    %****Step(3): update longitudinal vehilce model with inertial delay***%
    Ts = MPCParameters.Ts; % 50ms
    StateSpaceModel.A =  [1      Ts;
                          0      1];
    StateSpaceModel.B =  [0;     1]; 
    StateSpaceModel.C =  [1,    0];
    %****Step(4):  MPC formulation;********************%
    %Update Theta and PHI for future states prediction
    [PHI, THETA] = func_Update_PHI_THETA(StateSpaceModel, MPCParameters);

    %Update H and f for cost function J
    [H, f, g] = func_Update_H_f(kesi, SpeedProfile, PHI, THETA, MPCParameters); 
    
    %****Step(5):  Call qp-solver********************%
    switch MPCParameters.qp_solver,
        case 0 % default qp-solver: quadprog
            [A, b, Aeq, beq, lb, ub] = func_Constraints_du_quadprog(MPCParameters, a_x);
            options = optimset('Display','off', ...
                            'TolFun', 1e-8, ...
                            'MaxIter', 2000, ...
                            'Algorithm', 'active-set', ...
                            'FinDiffType', 'forward', ...
                            'RelLineSrchBnd', [], ...
                            'RelLineSrchBndDuration', 1, ...
                            'TolConSQP', 1e-8); 
            warning off all  % close the warnings during computation     

            U0 = WarmStart;           
            [U, FVAL, EXITFLAG] = quadprog(H, g, A, b, Aeq, beq, lb, ub, U0, options); %
            WarmStart = shiftHorizon(U);     % Prepare restart, nominal close loop 
            if (1 ~= EXITFLAG) %if optimization NOT succeeded.
                U(1) = 0.0;
                fprintf('MPC solver not converged!\n');                  
            end
            a_des =  U(1);
 
        case 1 % qpOASES
            [A, lb, ub, lbA, ubA] = func_Constraints_du_qpOASES(MPCParameters, a_x);
            options = qpOASES_options('default', ...
                                'printLevel', 0); 

            %=======================USE QP==================%
            [U, FVAL, EXITFLAG, iter, lambda] = qpOASES(H, g, A, lb, ub, lbA, ubA, options); %

            %=======================USE SQP==================%
    %         try
    %             H=sparse(H);
    %             A=sparse(A);
    %         catch
    %             fprintf('qpOASES Error reported\n'); 
    %         end
    %         if (qpOASES_hotstart_flag)
    %             [qpOASES_QP, U, FVAL, EXITFLAG, iter, lambda] = qpOASES_sequence('i', H, g, A, lb, ub, lbA, ubA, options);
    %             qpOASES_hotstart_flag = 1;
    %         else    
    %             [U, FVAL, EXITFLAG, iter, lambda] = qpOASES_sequence('m', qpOASES_QP, H, g, A, lb, ub, lbA, ubA, options); %
    %         end
            if (0 ~= EXITFLAG) %if optimization NOT succeeded.
                U(1) = 0.0;
                fprintf('MPC solver: qpOASES not converged!\n');                  
            end
            a_des =  U(1);

        case 2 % CVXGEN
            %--����License���ƣ����鲻�ṩCVXGEN���solver�����߿���������
            [vars, status] = MPC_Speed_Controller_CVXGEN(kesi, SpeedProfile, MPCParameters);
            if (1 == status.converged) %if optimization succeeded.
                a_des = vars.u_0; 
            else
                a_des = 0;
                fprintf('MPC solver not converged!\n');                  
            end

        otherwise % Unexpected flags %
            error(['unexpected qp-solver, Sol_method=',num2str(flag)]); % Error handling
    end %  end of switch 

end % end of if Initialflag < 1 % 

    %****Step(6):  �������ļ��ٶ�����Throttle��Brake;********************%
    [Throttle, Brake] = func_AccelerationTrackingController(a_des);

t_Elapsed = toc( t_Start ); %computation time 

sys = [Throttle; Brake;t_Elapsed; Vx; a_x; a_des]; 
% end  %End of mdlOutputs.

%==============================================================
% sub functions
%============================================================== 
function [Vref] = func_SineSpeed(Index, MPCParameters)
%����������ʽ�������ٶ�����
    %****Sine wave parameters
    T = 50; %�����ٶ����ߵ����ڣ�unit: s
    freq = 1/T; %�����ٶ����ߵ�Ƶ�ʣ�unit: Hz
    Amplit = 10;%�����ٶ����ߵķ�ֵ
    offst = 20; %�����ٶ����ߵ�ƫ��
    
    Ts = MPCParameters.Ts; %����ʱ��=0.05��unit: s
    Np = MPCParameters.Np; % Ԥ��ʱ��30
    Vref = cell(Np,1);
    t0 = Index*Ts;

    for i = 1:1:Np
        t = t0 + i*Ts;
        Vref{i,1}   =   Amplit*sin(2*pi*freq*t) + offst;   
    end
   
% end %EoF

function [Vref] = func_ConstantSpeed(InitialGapflag, MPCParameters)
% ���ɽ�����ʽ�������ٶ�����    
    Ts = MPCParameters.Ts; %����ʱ��=0.05��unit: s
    Np = MPCParameters.Np; % Ԥ��ʱ��30
    Vref = cell(Np,1);
    
    % �Զ�����ݵ���ʽ
    if InitialGapflag < 400
        Vset = 10;
    else
        if InitialGapflag < 800
            Vset = 10;
        else
            if InitialGapflag < 1500
                Vset = 20;
            else
                Vset = 5;
            end
        end
    end

    for i = 1:1:Np
        Vref{i,1}   =   Vset;   
    end

% end %EoF

function [Throttle, Brake] = func_AccelerationTrackingController(ahopt)
% ������λ���������������ٶ�ת��Ϊ���ſ��������ƶ�����ѹ��������
    K_brake         = 0.3;
    K_throttle      = 0.1; %0.05;
    Brake_Sat       = 15;
    Throttle_Sat    = 1;

    if ahopt < 0 % Brake control
        Brake = K_brake * ahopt;
        if Brake > Brake_Sat
            Brake = Brake_Sat;
        end
        Throttle = 0;
    else % throttle control 
        Brake       = 0;
        Throttle    = K_throttle  *ahopt;
        if Throttle > Throttle_Sat
            Throttle = Throttle_Sat;
        end
        if Throttle < 0
            Throttle = 0;
        end

    end
% end %EoF

function u0 = shiftHorizon(u) %shift control horizon
    u0 = [u(:,2:size(u,2)), u(:,size(u,2))];  %  size(u,2))
    
function [PHI, THETA] = func_Update_PHI_THETA(StateSpaceModel, MPCParameters)
%***************************************************************%
% Ԥ��������ʽ Y(t)=PHI*kesi(t)+THETA*DU(t) 
% Y(t) = [Eta(t+1|t) Eta(t+2|t) Eta(t+3|t) ... Eta(t+Np|t)]'
%***************************************************************%
    Np = MPCParameters.Np;
    Nc = MPCParameters.Nc;
    Nx = MPCParameters.Nx;
    Ny = MPCParameters.Ny;
    Nu = MPCParameters.Nu;
    A = StateSpaceModel.A;
    B = StateSpaceModel.B;
    C = StateSpaceModel.C;

    PHI_cell=cell(Np,1);                            %PHI=[CA CA^2  CA^3 ... CA^Np]' 
    THETA_cell=cell(Np,Nc);                         %THETA
    for j=1:1:Np
        PHI_cell{j,1}=C*A^j;                       %  demision:Ny* Nx
        for k=1:1:Nc
            if k<=j
                THETA_cell{j,k}=C*A^(j-k)*B;        %  demision:Ny*Nu
            else 
                THETA_cell{j,k}=zeros(Ny,Nu);
            end
        end
    end
    PHI=cell2mat(PHI_cell);    % size(PHI)=[(Ny*Np) * Nx]
    THETA=cell2mat(THETA_cell);% size(THETA)=[Ny*Np Nu*Nc]
% end %EoF


function[H, f, g] = func_Update_H_f(kesi, SpeedProfile, PHI, THETA, MPCParameters)
%***************************************************************%
% trajectory planning
%***************************************************************%
    Np = MPCParameters.Np;
    Nc = MPCParameters.Nc;   
    Q  = MPCParameters.Q;
    R  = MPCParameters.R;
        
    Qq = kron(eye(Np),Q);  %           Q = [Np*Nx] *  [Np*Nx] 
    Rr = kron(eye(Nc),R);  %           R = [Nc*Nu] *  [Nc*Nu]

    Vref = cell2mat(SpeedProfile); 
    error = PHI * kesi;    %[(Nx*Np) * 1]

    H = THETA'*Qq*THETA + Rr;  
    f = (error' - Vref')*Qq*THETA;
    g = f';
% end %EoF

function  [A, b, Aeq, beq, lb, ub] = func_Constraints_du_quadprog(MPCParameters, um)
%************************************************************************%
% generate the constraints of the vehicle
%  
%************************************************************************%
    Np   = MPCParameters.Np;
    Nc   = Np;    
    dumax = MPCParameters.dumax;
    umin = MPCParameters.umin;  
    umax = MPCParameters.umax;  
    Umin = kron(ones(Nc,1),umin);
    Umax = kron(ones(Nc,1),umax);
    Ut   = kron(ones(Nc,1),um);
%----(1) A*x<=b----------%
    A_t=zeros(Nc,Nc);
    for p=1:1:Nc
        for q=1:1:Nc
            if p >= q 
                A_t(p,q)=1;
            else 
                A_t(p,q)=0;
            end
        end 
    end 
    A_cell=cell(2,1);
    A_cell{1,1} = A_t; %
    A_cell{2,1} = -A_t;
    A=cell2mat(A_cell);  %
    
    
    b_cell=cell(2, 1);
    b_cell{1,1} = Umax - Ut; %
    b_cell{2,1} = -Umin + Ut;
    b=cell2mat(b_cell);  % 

%----(2) Aeq*x=beq----------%
    Aeq = [];
    beq = [];

%----(3) lb=<x<=ub----------%
    lb=kron(ones(Nc,1),-dumax);
    ub=kron(ones(Nc,1),dumax);
% end %EoF

function [A_t, lb, ub, lbA, ubA] = func_Constraints_du_qpOASES(MPCParameters, um)
    Np   = MPCParameters.Np;
    Nc   = Np;    
    dumax = MPCParameters.dumax;
    umin = MPCParameters.umin;
    umax = MPCParameters.umax;  
    Umin = kron(ones(Nc,1), umin);
    Umax = kron(ones(Nc,1), umax);
    Ut   = kron(ones(Nc,1),um);
%----(1) lbA <= A_t*x<=ubA----------%
    A_t=zeros(Nc,Nc);
    for p=1:1:Nc
        for q=1:1:Nc
            if p >= q 
                A_t(p,q)=1;
            else 
                A_t(p,q)=0;
            end
        end 
    end 

    ubA = Umax - Ut; %
    lbA = Umin - Ut;
%---- lb=<x<=ub----------%
    lb=kron(ones(Nc,1),-dumax);
    ub=kron(ones(Nc,1),dumax);
% end %EoF

