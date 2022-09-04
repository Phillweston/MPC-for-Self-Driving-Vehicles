function [WPIndex, RefP, RefU, Uaug, Uaug_0, PrjP, Roll_BaknR] = func_RefTraj_LocalPlanning_TwoTimeScales_Spatial_Integrated( MPCParameters, VehiclePara, WayPoints_Index, WayPoints_Collect, VehStateMeasured)
%***************************************************************%
%  ������PrjP��
% �����ҵ�ȫ��·���Ͼ��복������ĵ�
% ��Σ����ݲ�ͬ�Ĳ���������sѡ��һЩ�вο��㲢ת������������ϵ�¡��ο������Ϣ����[s,x,y,bank]
% �ٴΣ��Գ�������ϵ�µ�x,y��Bezier���߲�ֵ����������������������ĺ���Ǻ����ʡ�4
% ͬʱ���Ե�·�Ĳ����s����������ϼ�����
% ��󣬽��ο���Ĳ�������RefP, RefU��Uaug

% Input:
% MPCParameters��
% WayPoints_Index
% WayPoints_Collect
% VehStateMeasured
% 
% Output:
% WPIndex�� 
%     > 0��Normal, WPIndex = index_min;
%     0:error,index_min<1
%     -1: index_min = WPNum,����ȫ��·���ľ�ͷ��ͣ��

%---------------------------------------------------------------%
% Published by: Kai Liu
% Email:leoking1025@gmail.com
% My homepage: https://sites.google.com/site/kailiumiracle/  
%***************************************************************%

%*********** Parameters Initialization *************************% 
    L       = VehiclePara.L;   % �������
    Np      = MPCParameters.Np;% Ԥ��ʱ��
    Ns      = MPCParameters.Ns; % Tsplit
    Ts      = MPCParameters.Ts; % Set the sample time of near term
    Tsl     = MPCParameters.Tsl;% Set the sample time of long term   

    %------Measured or Estimated vehicle status
    Vel     = VehStateMeasured.x_dot;   % 20; % 
    PosX    = VehStateMeasured.X;
    PosY    = VehStateMeasured.Y;
    PosPsi  = VehStateMeasured.phi;      
    Roll_Shad = VehStateMeasured.Roll_Shad;%rad
%     Ax      = VehStateMeasured.Ax;
%     fwa     = VehStateMeasured.fwa; 
    
%*********** WaypointData2VehicleCoords ************************% 
    ds          = 0.1;%m
    WPNum       = length(WayPoints_Collect(:,1));
    
    %--------���ҵ��ο�·���Ͼ��복������ĵ�--------------------------%  
    Dist_MIN    = 1000;
    index_min   = 0;
    for i=WayPoints_Index:1:WPNum 
        deltax  = WayPoints_Collect(i,2) - PosX;
        deltay  = WayPoints_Collect(i,3) - PosY;
        Dist    = sqrt(power(deltax,2) + power(deltay,2)); %·�㵽�������ĵľ���
        if Dist < Dist_MIN
            Dist_MIN = Dist; 
            index_min = i;
        end
    end
    if (index_min < 1) 
        WPIndex = -1; %���û���ҵ��򡣡�
    else if ( index_min >= WPNum)
            WPIndex = -2; %���û���ҵ��򡣡�
        else
            WPIndex = index_min;
        end
    end
    

    if( WPIndex > 0 )   % ����ҵ��������
    %% ѡ��ͶӰ�㣬 ȫ��·����ѡ��ο��㣬��ת�������������¡�ͬʱѡ��s�Ͷ�Ӧ��Bank angle        
        %--------------ͨ��������ͶӰ��--------------------------%
        [PPx,PPy,ey]=func_GetProjectPoint(WayPoints_Collect(index_min,2),... 
                                            WayPoints_Collect(index_min,3),... 
                                            WayPoints_Collect(index_min+1,2),... 
                                            WayPoints_Collect(index_min+1,3),... 
                                            PosX,... 
                                            PosY);
        Dy          = WayPoints_Collect(index_min+1,3) - WayPoints_Collect(index_min,3);
        Dx          = WayPoints_Collect(index_min+1,2) - WayPoints_Collect(index_min,2);
        Psi0        = atan2(Dy, Dx);  
        epsi        = Psi0 - PosPsi;
        
        PrjP.ey     = -ey;
        PrjP.epsi   = -epsi;        
        PrjP.Velr   = Vel;                                        
        PrjP.xr     = PPx;
        PrjP.yr     = PPy;
        PrjP.psir   = Psi0;
%         Kprj        = 0; Ĭ�� ͶӰ�������Ϊ�㣬��Ϊһ��ֱ��
        PrjP.fwar   = 0; %atan(Kprj*L);  

        %-------------------i=1:Ns--���ݳ�����ȫ�ֲο�·����ѡ��ο���-------%
        Global_x        = [];
        Global_y        = [];  % ��ȫ��·����ѡ���·����      
        Local_Sx        = [];
        Local_Sy        = [];
        Local_SS        = [];
        Local_SB        = []; %��Զ�ʱ��
        StepLength_S    = Vel * Ts *  (Ns+1);% ���һ����Ϊ������������ʱ׼��
        Ns_index        = index_min; 
        
%         %--index_min �� index_min+1 ֮���ͶӰ��
%         deltax          = PPx - PosX;
%         deltay          = PPy - PosY; 
%         CarCoord_x      = deltax * cos(PosPsi) + deltay * sin(PosPsi);
%         CarCoord_y      = deltay * cos(PosPsi) - deltax * sin(PosPsi);  
%         Local_Sx        = [Local_Sx; CarCoord_x];
%         Local_Sy        = [Local_Sy; CarCoord_y];           
%         Global_x        = [Global_x; PPx];
%         Global_y        = [Global_y; PPy];
%         
%         Local_SS        = [Local_SS; WayPoints_Collect(i,7)];
%         Local_SB        = [Local_SB; WayPoints_Collect(i,8)];       
%         %--index_min+1 
%         deltax          = WayPoints_Collect(index_min+1,2) - PosX;
%         deltay          = WayPoints_Collect(index_min+1,3) - PosY;
%         CarCoord_x      = deltax * cos(PosPsi) + deltay * sin(PosPsi);
%         CarCoord_y      = deltay * cos(PosPsi) - deltax * sin(PosPsi);    
%         Local_Sx        = [Local_Sx; CarCoord_x];
%         Local_Sy        = [Local_Sy; CarCoord_y];
%         Global_x        = [Global_x; WayPoints_Collect(index_min+1,2)];
%         Global_y        = [Global_y; WayPoints_Collect(index_min+1,3)];
%         
        tempDx          = WayPoints_Collect(index_min+1,2) - PPx;
        tempDy          = WayPoints_Collect(index_min+1,3) - PPy;
        Dist_1          = sqrt(power(tempDx,2) + power(tempDy,2)); %·�㵽ͶӰ��ľ��� 

        for i=index_min:1:WPNum %�ڲο�·����ѡ��ο���,��ͨ��������תת������������ϵ��
            Global_x        = [Global_x; WayPoints_Collect(i,2) ];
            Global_y        = [Global_y; WayPoints_Collect(i,3) ];  %��ȡ��ȫ��·����
            
            deltax          = WayPoints_Collect(i,2) - PosX;
            deltay          = WayPoints_Collect(i,3) - PosY;
            CarCoord_x      = deltax * cos(PosPsi) + deltay * sin(PosPsi);
            CarCoord_y      = deltay * cos(PosPsi) - deltax * sin(PosPsi); % ȫ��·����ת�����ֲ�������              
            Local_Sx        = [Local_Sx; CarCoord_x];
            Local_Sy        = [Local_Sy; CarCoord_y];  %�洢�ֲ������µĵ� 
    
            
            Local_SS        = [Local_SS; WayPoints_Collect(i,7)];
            Local_SBL       = [Local_SB; WayPoints_Collect(i,8)];
            Local_SBR       = [Local_SB; WayPoints_Collect(i,9)];
            
            Ns_index        = i-1;            
            Dist_SumS       = Dist_1 + WayPoints_Collect(i,7) - WayPoints_Collect(index_min+1,7);  
            if(Dist_SumS >= StepLength_S)
                break;
            end            
        end % end of   for I=index_min+1:1:WPNum           
         
        %------------Ns:Np---------%
        Local_Lx        = [];
        Local_Ly        = [];
        Local_LS        = [];
        Local_LB        = [];
        StepLength_L    = Vel * Tsl * (Np-Ns+1);% ���һ����Ϊ������������ʱ׼��
        Dist_SumL       = 0;      %
        for i=Ns_index:1:WPNum %�ڲο�·����ѡ��ο���,��ͨ��������תת������������ϵ��
            Global_x        = [Global_x; WayPoints_Collect(i,2) ];
            Global_y        = [Global_y; WayPoints_Collect(i,3) ];       
            
            deltax          = WayPoints_Collect(i,2) - PosX;
            deltay          = WayPoints_Collect(i,3) - PosY;
            CarCoord_x      = deltax * cos(PosPsi) + deltay * sin(PosPsi);
            CarCoord_y      = deltay * cos(PosPsi) - deltax * sin(PosPsi); % ת�����ֲ�������             
            Local_Lx        = [Local_Lx; CarCoord_x];
            Local_Ly        = [Local_Ly; CarCoord_y]; % ת�����ֲ������� 
  
            
            Local_LS        = [Local_LS; WayPoints_Collect(i,7)];
            Local_LBL       = [Local_LB; WayPoints_Collect(i,8)];
            Local_LBR       = [Local_LB; WayPoints_Collect(i,9)];
            
            Dist_SumL       = WayPoints_Collect(i,7) - WayPoints_Collect(Ns_index, 7 );
            if(Dist_SumL >= StepLength_L)
                break;
            end  
        end % end of   for i=Ns_index+1:1:WPNum   
        
        %%
        %------------����ʽ�������------------%
        if(Dist_SumS < StepLength_S) || (Dist_SumL < StepLength_L)
           WPIndex = 0; %���û���ҵ��򡣡� % reaching the end ... %--����û�п���������ȫ��·����󼸸���ʱ������������걸���п��ܻᱨ������           
        else
             %----�Զ̲�����Bezier������ϣ��ŵ����ڿ��Զ������-----%
            MatS(:,1)=Local_Sx; 
            MatS(:,2)=Local_Sy;             
            [ps0,ps1,ps2,ps3,ts] = func_FindBezierControlPointsND(MatS,'u'); %uniform parameterization
            Scale                = round(Vel*Ts/ds);
            tlocS                = linspace(0,1,Scale*(Ns+1)+1);   %����㵽�յ�Ⱦ�=0.1m����,����Ns+1���Σ�Scale*��Ns+1��+1����
            MatLocalInterpS      = func_bezierInterp( ps0, ps1, ps2, ps3,tlocS);   % ���߲�ֵ�õ�������
            
            MatSB(:,1)      = Local_SS; 
            MatSB(:,2)      = Local_SBR;             
            [psb0,psb1,psb2,psb3,tsb] = func_FindBezierControlPointsND(MatSB,'u'); %uniform parameterization
            tlocS                = linspace(0,1,Ns+2);   %����㵽�յ�Ⱦ����,����Np+1���Σ���Np+2������
            MatLocalInterpSB     = func_bezierInterp( psb0,psb1,psb2,psb3,tlocS);   % ���߲�ֵ�õ�������            
            
            Bezier_Sx       = zeros(Ns,1);
            Bezier_Sy       = zeros(Ns,1);
            Bezier_Spsi     = zeros(Ns,1);
            Bezier_SK       = zeros(Ns,1);
            Bezier_Sphi_t   = zeros(Ns,1);            
            for i = 2:1:length(MatLocalInterpSB(:,1))-1
                Bezier_Sx(i-1)    = MatLocalInterpS(Scale*(i-1),1);
                Bezier_Sy(i-1)    = MatLocalInterpS(Scale*(i-1),2);
                tempDx            = MatLocalInterpS(Scale*(i-1)+1,1) - MatLocalInterpS(Scale*(i-1),1);
                tempDy            = MatLocalInterpS(Scale*(i-1)+1,2) - MatLocalInterpS(Scale*(i-1),2);
                Bezier_Spsi(i-1)  = atan2(tempDy, tempDx);
                
%                 Bezier_SK(i-1)    = func_CalPathCurve(MatLocalInterpS(Scale*(i-1)-1,1),... 	% XA
%                                        MatLocalInterpS(Scale*(i-1)-1,2),...    % YA
%                                        MatLocalInterpS(Scale*(i-1),1),...      % XB
%                                        MatLocalInterpS(Scale*(i-1),2),...      % YB
%                                        MatLocalInterpS(Scale*(i-1)+1,1),...    % XC
%                                        MatLocalInterpS(Scale*(i-1)+1,2));      % YC
%  
                Bezier_SK(i-1)    = func_CalPathCurve_Patent(MatLocalInterpS(Scale*(i-1)-1,1),... 	% XA
                                       MatLocalInterpS(Scale*(i-1)-1,2),...    % YA
                                       MatLocalInterpS(Scale*(i-1),1),...      % XB
                                       MatLocalInterpS(Scale*(i-1),2),...      % YB
                                       MatLocalInterpS(Scale*(i-1)+1,1),...    % XC
                                       MatLocalInterpS(Scale*(i-1)+1,2));      % YC
%                 
%                 Bezier_SK(i-1)    = func_CalPathCurve_YU(MatLocalInterpS(Scale*(i-1)-1,1),... 	% XA
%                                        MatLocalInterpS(Scale*(i-1)-1,2),...    % YA
%                                        MatLocalInterpS(Scale*(i-1),1),...      % XB
%                                        MatLocalInterpS(Scale*(i-1),2),...      % YB
%                                        MatLocalInterpS(Scale*(i-1)+1,1),...    % XC
%                                        MatLocalInterpS(Scale*(i-1)+1,2));      % YC
                                   
                Bezier_Sphi_t(i-1) = MatLocalInterpSB(i,2);                  
            end % end of  for i = 2:1:length(MatLocalInterp(:,1))-1
            

            %----�Գ������� ����Bezier�������-----%
            MatL(:,1)=Local_Lx; 
            MatL(:,2)=Local_Ly;             
            [pL0,pL1,pL2,pL3,tL] = func_FindBezierControlPointsND(MatL,'u'); %uniform parameterization
            Scale                = round(Vel*Tsl/ds);
            tlocL                = linspace(0,1,Scale*(Np-Ns+1)+1);   %����㵽�յ�Ⱦ����,����Np-Ns+1���Σ�Scale*��Np-Ns+1��+1=Scale(Np-Ns)+11����
            MatLocalInterpL      = func_bezierInterp( pL0, pL1, pL2, pL3,tlocL);   % ���߲�ֵ�õ�������
            
            MatLB(:,1)=Local_LS; 
            MatLB(:,2)=Local_LBR;             
            [ps0,ps1,ps2,ps3,tL] = func_FindBezierControlPointsND(MatLB,'u'); %uniform parameterization
            tlocL                = linspace(0,1,Np-Ns+2);   %����㵽�յ�Ⱦ����,����Np+1���Σ���Np+2������
            MatLocalInterpLB     = func_bezierInterp( ps0, ps1, ps2, ps3,tlocL);   % ���߲�ֵ�õ�������    
            
            Bezier_Lx       = zeros(Np-Ns,1);
            Bezier_Ly       = zeros(Np-Ns,1);
            Bezier_Lpsi     = zeros(Np-Ns,1);
            Bezier_LK       = zeros(Np-Ns,1);
            Bezier_Lphi_t   = zeros(Np-Ns,1);  
            for i = 2:1:length(MatLocalInterpLB(:,1))-1
                Bezier_Lx(i-1)     = MatLocalInterpL(Scale*(i-1),1);
                Bezier_Ly(i-1)     = MatLocalInterpL(Scale*(i-1),2);
                tempDx             = MatLocalInterpL(Scale*(i-1)+1,1) - MatLocalInterpL(Scale*(i-1),1);
                tempDy             = MatLocalInterpL(Scale*(i-1)+1,2) - MatLocalInterpL(Scale*(i-1),2);
                Bezier_Lpsi(i-1)   = atan2(tempDy, tempDx);
                
%                 Bezier_LK(i-1)     = func_CalPathCurve(MatLocalInterpL(Scale*(i-1)-1,1),... 	% XA
%                                        MatLocalInterpL(Scale*(i-1)-1,2),...    % YA
%                                        MatLocalInterpL(Scale*(i-1),1),...      % XB
%                                        MatLocalInterpL(Scale*(i-1),2),...      % YB
%                                        MatLocalInterpL(Scale*(i-1)+1,1),...    % XC
%                                        MatLocalInterpL(Scale*(i-1)+1,2));      % YC
%                                    
                Bezier_LK(i-1)     = func_CalPathCurve_Patent(MatLocalInterpL(Scale*(i-1)-1,1),... 	% XA
                                       MatLocalInterpL(Scale*(i-1)-1,2),...    % YA
                                       MatLocalInterpL(Scale*(i-1),1),...      % XB
                                       MatLocalInterpL(Scale*(i-1),2),...      % YB
                                       MatLocalInterpL(Scale*(i-1)+1,1),...    % XC
                                       MatLocalInterpL(Scale*(i-1)+1,2));      % YC
%                                    
%                 Bezier_LK(i-1)     = func_CalPathCurve_YU(MatLocalInterpL(Scale*(i-1)-1,1),... 	% XA
%                                        MatLocalInterpL(Scale*(i-1)-1,2),...    % YA
%                                        MatLocalInterpL(Scale*(i-1),1),...      % XB
%                                        MatLocalInterpL(Scale*(i-1),2),...      % YB
%                                        MatLocalInterpL(Scale*(i-1)+1,1),...    % XC
%                                        MatLocalInterpL(Scale*(i-1)+1,2));      % YC                   
                                   
                Bezier_Lphi_t(i-1) = MatLocalInterpLB(i,2);
                
            end % end of  for i = 2:1:length(MatLocalInterp(:,1))-1


            
    %%
        RefP    = cell(Np,1);        
        RefU    = cell(Np,1); 
        for i = 1:1:Np
            if i <= Ns
               RefU{i,1} = atan(Bezier_SK(i)*L);                 
               RefP{i,1} = [Bezier_Sx(i);
                            Bezier_Sy(i);
                            Bezier_Spsi(i)]; 
            else
               RefU{i,1} = atan(Bezier_LK(i-Ns)*L); 
               RefP{i,1} = [Bezier_Lx(i-Ns);
                            Bezier_Ly(i-Ns);
                            Bezier_Lpsi(i-Ns)];                     
            end
        end  
        

        Uaug    = cell(Np,1);  
        
        Uaug_0  = [0;0]; % [MatLocalInterpSB(1,2); 0];  %          
        for i = 1:1:Np %�����ǵ�·���ʺ���ǵ�Ӱ��
            if i <= Ns                     
                Uaug{i,1} = [0;0]; 
            else                   
                Uaug{i,1} = [0;0]; 
            end
        end  

%         Uaug_0  = [0; Bezier_SK(1)];  %  [0;0]; %      
%         for i = 1:1:Np %ֻ���ǵ�·����
%             if i <= Ns                     
%                 Uaug{i,1} = [0; Bezier_SK(i)];
%             else                   
%                 Uaug{i,1} = [0; Bezier_LK(i-Ns)];
%             end
%         end  

%         Uaug_0  = [Roll_Shad; 0];  %  [MatLocalInterpSB(1,2); 0];  %  
%         for i = 1:1:Np %ֻ����·����ǵ�Ӱ��
%             if i <= Ns                     
%                 Uaug{i,1} = [Bezier_Sphi_t(i); 0];
%             else                   
%                 Uaug{i,1} = [Bezier_Lphi_t(i-Ns); 0];
%             end
%         end  
        
%         Uaug_0  = [Roll_Shad; Bezier_SK(1)];  %[MatLocalInterpSB(1,2); Bezier_SK(1)];  %      
%         for i = 1:1:Np %���ǵ�·���ʺ���ǵ�Ӱ��
%             if i <= Ns                     
%                 Uaug{i,1} = [Bezier_Sphi_t(i); Bezier_SK(i)];
%             else                   
%                 Uaug{i,1} = [Bezier_Lphi_t(i-Ns); Bezier_LK(i-Ns)];
%             end
%         end  

        Roll_BaknR = MatLocalInterpSB(1,2);
        end % end of if(Dist_SumS < StepLength_S) || (Dist_SumL < StepLength_L)
        
    end % end of if( WPIndex > 0 )   % ����ҵ��������

% %--------Plot local points and the fitted polynomial----------------%
% figure
% plot(Local_Sx,Local_Sy,'b*');
% hold on
% plot(Local_Lx,Local_Ly,'bo');    
% plot(Global_x,Global_y,'k.');  
% plot(Bezier_Sx,Bezier_Sy,'r+'); 
% plot(Bezier_Lx,Bezier_Ly,'ro'); 

end % end of function 


%==============================================================%
% sub functions
%==============================================================%   
function K=GetPathHeading(Xb,Yb,Xn,Yn)
    %***Way I.��Heading Angle ��[-pi,pi]֮�� *******%
    AngleY=Yn-Yb;
    AngleX=Xn-Xb;
    K= atan2(AngleY, AngleX);
    
    %***Way II. ��Heading Angle ��0~2*pi֮�� *******%
%     AngleY=Yn-Yb;
%     AngleX=Xn-Xb;    
%     
%     if Xb==Xn
%         if Yn>Yb
%             K=pi/2;
%         else
%             K=3*pi/2;
%         end
%     else
%         if Yb==Yn
%             if Xn>Xb
%                 K=0;
%             else
%                 K=pi;
%             end
%         else
%             K=atan(AngleY/AngleX);
%         end    
%     end
% 
%     %****����K,ʹ֮��0~360��֮��*****%
%    if (AngleY>0&&AngleX>0)%��һ����
%         K=K;
%     elseif (AngleY>0&&AngleX<0)||(AngleY<0&&AngleX<0)%�ڶ���������
%         K=K+pi;
%     else if (AngleY<0&&AngleX>0)%��������
%             K=K+2*pi;  
%         else
%             K=K;
%         end
%    end
    
end % end of function

function [PPx,PPy,de]=func_GetProjectPoint(Xb,Yb,Xn,Yn,Xc,Yc)
%-------------------------------------------------------%
% de��㵽ֱ�ߵľ��벻ͬ�������෴��
% �㵽ֱ�ߵľ��룺�����Ҹ�
%-------------------------------------------------------%

    if Xn==Xb
        x=Xn;
        y=Yc;
        de=Xc-Xn;
    else if Yb==Yn
            x=Xc;
            y=Yn;
            de=Yn-Yc;
        else
            DifX=Xn-Xb;
            DifY=Yn-Yb;
            Kindex=DifY/DifX;
            bindex=Yn-Kindex*Xn;
            
            K=(-1)*1/Kindex;
            b=Yc-K*Xc;
            x=(bindex-b)/(K-Kindex);
            y=K*x+b;
            de=(Kindex*Xc+bindex-Yc)/sqrt(1+Kindex*Kindex);
        end     
    end
    PPx=x;
    PPy=y;
       
end

function K=func_CalPathCurve(XA,YA,XB,YB,XC,YC)
    %% ͨ����������Բ�ģ�����Բ�ĵ�����һ����ľ���
    %�ֱ�������ֱ�ߵ�б��
    if XB==XA
        mr=inf;
    else
        mr=(YB-YA)/(XB-XA);    
    end
    if XC==XB
        mt=inf;
    else
        mt=(YC-YB)/(XC-XB);    
    end

   %���ݲ�ͬ��б���������,mtdao=1/mt;mrsubmt=1/(2*(mr-mt));
    if mr==mt
        Rff=inf;
    else if mt==0
            if mr==inf
                Rff=sqrt(power((XA-XC),2)+power((YA-YC),2))/2;
            else
                mrsubmt=1/(2*(mr-mt));
                Xff=(mr*mt*(YC-YA)+mr*(XB+XC)-mt*mrsubmt*(XA+XB));
                Yff=(YB+YA)/2-(Xff-(XB+XA)/2)/mr;
                Rff=sqrt(power((XA-Xff),2)+power((YA-Yff),2));           
            end
        elseif mt==inf
            if mr==0
                Rff=sqrt(power((XA-XC),2)+power((YA-YC),2))/2;
            else
                Yff=(YB+YC)/2;
                Xff=(XA+XB)/2-mr*(YC-YA)/2;
                Rff=sqrt(power((XA-Xff),2)+power((YA-Yff),2));     
            end        
        else
            mtdao=1/mt;
            if mr==0
                mrsubmt=1/(2*(mr-mt));
                Xff=(mr*mt*(YC-YA)+mr*(XB+XC)-mt*mrsubmt*(XA+XB));
                Yff=(YB+YC)/2-mtdao*(Xff-(XB+XC)/2);
                Rff=sqrt(power((XA-Xff),2)+power((YA-Yff),2));            
            elseif mr==inf
                Yff=(YA+YB)/2;
                Xff=(XB+XC)/2+mt*(YA-YC)/2;
                Rff=sqrt(power((XA-Xff),2)+power((YA-Yff),2));
            else
                mrsubmt=1/(2*(mr-mt));
                Xff=(mr*mt*(YC-YA)+mr*(XB+XC)-mt*mrsubmt*(XA+XB));
                Yff=(YB+YC)/2-mtdao*(Xff-(XB+XC)/2);
                Rff=sqrt(power((XA-Xff),2)+power((YA-Yff),2));  
            end
        end    
    end
    %%
    %ͨ���жϺ���ǵı仯�������ж����ʵ�����
    K1=GetPathHeading(XA,YA,XB,YB);
    K2=GetPathHeading(XB,YB,XC,YC);
    if K2>K1 %�нǱ����ʱ��
        Rff=Rff;
    else %�нǱ�С��˳ʱ�룬K2<K1
        Rff=-1*Rff;
    end
    
    K = 1/Rff;
end

function K=func_CalPathCurve_Patent(XA,YA,XB,YB,XC,YC)
    %% 
    x_dot       = XC - XA;
    y_dot       = YC - YA;
    x_dotdot    = XC + XA - 2*XB;
    y_dotdot    = YC + YA - 2*YB;
    temp        = x_dot*x_dot + y_dot*y_dot;
    K= 4*(x_dot*y_dotdot - x_dotdot*y_dot )/ power(temp, 1.5);

end

function curvature = func_CalPathCurve_YU(X1,Y1,X2,Y2,X3,Y3)
    %-----------caculate the radius of the circle first 
    % side one  
    delta_x = X2 - X1;  
    delta_y = Y2 - Y1;  
    a = sqrt(power(delta_x, 2.0) + power(delta_y, 2.0));  

    % side two  
    delta_x = X3 - X2;  
    delta_y = Y3 - Y2;  
    b = sqrt(power(delta_x, 2.0) + power(delta_y, 2.0));  

    % side three  
    delta_x = X1 - X3;  
    delta_y = Y1 - Y3;  
    c = sqrt(power(delta_x, 2.0) + power(delta_y, 2.0));  
    CLOSE_TO_ZERO = 0.01;
    if (a < CLOSE_TO_ZERO || b < CLOSE_TO_ZERO || c < CLOSE_TO_ZERO)   
        curvature = 0; 
    end
    
    %------------------------semiperimeter
    s = (a + b + c) / 2.0;  
    K = sqrt(abs(s * (s - a) * (s - b) * (s - c)));  
    curvature = 4 * K / (a * b * c);  
    
    %------------ determine the sign, using cross product(���)
    % 2ά�ռ��еĲ���ǣ� A x B = |A||B|Sin(��)
    % V1(x1, y1) X V2(x2, y2) = x1y2 �C y1x2  
    rotate_direction = (X2 - X1) *  (Y3 - Y2) - (Y2 - Y1) * (X3 - X2);  
    if(rotate_direction < 0) %ͨ���жϷ��ţ��ж�Sin(��)�ķ���
        %Sin(��)<0, ˳ʱ����ת������Ϊ��
        curvature = -curvature;  
    end

end








