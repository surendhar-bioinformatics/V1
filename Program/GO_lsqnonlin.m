function LSE_Lys_Prot = GO_lsqnonlin(param, tspan, Lys_P_ratio, EtaP,setting)
    if setting == 3
        Lys_P_init = ones(1,length(EtaP));
        [t,Lys_P] = ode15s(@(t,y0)PT_ODE(t,y0,log(2)./param, EtaP),tspan,Lys_P_init );
        LSE_Lys_Prot  = [Lys_P_ratio - Lys_P(:,1:end-1) [0; 0; 0; 0; 0]]; 
        LSE_Lys_Prot(isnan(LSE_Lys_Prot))= [];
    end
    if setting == 2
        Lys_P_init = ones(1,size(Lys_P_ratio,2));
        [t,Lys_P] = ode15s(@(t,y0)PT_ODE_Ratio(t,y0,[log(2)./param(1:end-1) param(end)] ),tspan,Lys_P_init);
        LSE_Lys_Prot  = [Lys_P_ratio - Lys_P(:,1:end)]; 
        LSE_Lys_Prot(isnan(LSE_Lys_Prot))= [];
    end
    
    if setting == 1
        Lys_P_init = ones(1,1+size(Lys_P_ratio,2));
        [t,Lys_P] = ode15s(@(t,y0)PT_ODE_Ratio(t,y0,[log(2)./param(1:end-1) param(end)]),tspan,Lys_P_init);
        LSE_Lys_Prot  = [Lys_P_ratio - Lys_P(:,2:end)]; 
        LSE_Lys_Prot(isnan(LSE_Lys_Prot))= [];
    end
        
end
