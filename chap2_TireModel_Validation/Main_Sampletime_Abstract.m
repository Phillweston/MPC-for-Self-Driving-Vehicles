function [sys,x0,str,ts] =Main_Sampletime_Abstract(t,x,u,flag)
%***************************************************************%
% ����Carsim sample time ��S��������֮��Ĺ�ϵ�� 
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
sizes.NumOutputs     = 38;  %S��������������������������������
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

%  End of mdlInitializeSizes

%==============================================================
% Update the discrete states, flag = 2�� mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%==============================================================
function sys = mdlUpdates(t,x,u)
%  ����û���õ�������̣��ں��ڵĳ���ģ�黯ʱ���Լ�������������ܡ�
    sys = x; 
    
% end     %End of mdlUpdate.

%==============================================================
% Calculate outputs, flag = 3�� mdlOutputs
% Return the block outputs. 
%==============================================================
function sys = mdlOutputs(t,x,u)
%t�ǲ���ʱ��, x��״̬����, u������(������simulinkģ�������)
    sys = u;
     
% end  %End of mdlOutputs.

