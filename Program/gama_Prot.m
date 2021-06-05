function [Glob_fit_Prot] = gama_Prot(data,parameters,OptiResStep1,Setting)
    %step-2 ;Optimization to get protein degredation/half-life values
    
    %opts = optimset('FinDiffRelStep',1e-3);
    opts            = optimoptions(@lsqnonlin, 'FiniteDifferenceStepSize',1e-3,'FiniteDifferenceType','central', 'MaxIterations', 50000);%,, 'MaxFunctionEvaluations', 5000
    opts2           = optimoptions(@lsqnonlin,'FiniteDifferenceStepSize',1e-3,'FiniteDifferenceType','central', 'MaxIterations', 2, 'MaxFunctionEvaluations', 2);%,
    ms              = MultiStart('UseParallel','always','Display','off');
    Glob_fit_Prot = []; min_free_lys_error = 100;
    for i = 1:length(data.se)-1
        fprintf('Step-2; Optimizing proteins-%d to %d, out of %d  with setting-%d\n',data.se(i)+1,data.se(i+1), data.se(end),Setting)
        number_param    = 1 + size(data.SILAC_data(:,data.se(i)+1:data.se(i+1)),2);%
        lb              = zeros(1,number_param); ub = [];
        Ansatz          = [data.Ansatz_(1, 2:number_param) OptiResStep1.Concen_ratio]; 
        fast_data       = data.Lys(2:end)'+ data.Lys(2:end)'*0.05;
        if Setting == 3 
            data.SILAC_data_temp    = [data.Lys' data.SILAC_data(:,data.se(i)+1:data.se(i+1))];
            data.Conc_temp          = [data.LysConc, data.ProtConc(data.se(i)+1:data.se(i+1)), parameters.tot_Lys-sum(data.ProtConc(data.se(i)+1:data.se(i+1)))];
            problem                 = createOptimProblem('lsqnonlin','x0',Ansatz,'objective',@(param)GO_fixLys_lsqnonlin(param, data.t,  data.SILAC_data_temp,data.Conc_temp, Setting, OptiResStep1.gama_Lys_best),'lb',lb,'ub',ub,'options',opts);
        elseif Setting == 2 
            data.SILAC_data_temp    = [data.Lys' data.SILAC_data(:,data.se(i)+1:data.se(i+1))];
            data.Conc_temp          = [0];
            problem                 = createOptimProblem('lsqnonlin','x0',Ansatz,'objective',@(param)GO_fixLys_lsqnonlin(param, data.t,  data.SILAC_data_temp,data.Conc_temp, Setting, OptiResStep1.gama_Lys_best),'lb',lb,'ub',ub,'options',opts);
        elseif Setting == 1
            data.SILAC_data_temp    = [data.SILAC_data(:,data.se(i)+1:data.se(i+1))];
            data.Conc_temp          = [0];
            problem                 = createOptimProblem('lsqnonlin','x0',Ansatz,'objective',@(param)GO_fixLys_lsqnonlin(param, data.t,  data.SILAC_data_temp,data.Conc_temp, Setting, OptiResStep1.gama_Lys_best),'lb',lb,'ub',ub,'options',opts);
        else
            fprintf('Error: Setting is not defined; please define the setting to calculate the half-lives\n')
        end
        Ansatz          = [data.Ansatz_(2:end, 2:number_param) repelem(OptiResStep1.Concen_ratio, size(data.Ansatz_,1)-1)'];
        custpts = CustomStartPointSet(Ansatz);
        [Gfit,~,~,~,solutions]  = run(ms,problem,custpts);
        if (Setting == 3) || (Setting == 2) || (Setting == 1)
            Error_free_Lys = 100; Gfit_final = [];
            for j =1 : length(solutions)
                if Setting == 3
                    Lys_P_init      = ones(1,number_param+1);
                    [t,Lys_P]       = ode15s(@(t,Lys_P)PT_ODE_fixLys(t,Lys_P,solutions(j).X,data.Conc_temp,OptiResStep1.gama_Lys_best),data.t,Lys_P_init);
                    Error_free_Lys_ = sum((Lys_P(:,1) - data.Lys').^2);
                elseif Setting == 2
                    Lys_P_init      = ones(1,number_param);
                    [t,Lys_P]       = ode15s(@(t,Lys_P)PT_ODE_Ratio_fixLys(t,Lys_P,solutions(j).X, OptiResStep1.gama_Lys_best),data.t,Lys_P_init);
                    Error_free_Lys_ = sum((Lys_P(:,1) - data.Lys').^2);
                elseif Setting == 1
                    Lys_P_init      = ones(1,number_param);
                    [t,Lys_P]       = ode15s(@(t,Lys_P)PT_ODE_Ratio_fixLys(t,Lys_P,solutions(j).X, OptiResStep1.gama_Lys_best),data.t,Lys_P_init);
                    fast_data        = [min(data.SILAC_data(2,:)) min(data.SILAC_data(3,:)) min(data.SILAC_data(4,:)) min(data.SILAC_data(5,:))]';
                    Error_proteins_only = sum(nansum((data.SILAC_data_temp(:,1:end) - Lys_P(:,2:end)).^2));
                    Error_free_Lys_ = Error_proteins_only;
                end
                temp = [2; 2; 2; 2];
                if (length(temp(Lys_P(2:end,1) <= fast_data)) > 0) && (Error_free_Lys_ < Error_free_Lys ) 
                    Error_free_Lys = Error_free_Lys_; 
                    Gfit_final = solutions(j).X;
                elseif Error_free_Lys_ < min_free_lys_error
                    min_free_lys_error       = Error_free_Lys_;
                    Gfit_withMinFreeLysError =  solutions(j).X;
                end
            end
            if length(Gfit_final) < 1 
                Gfit_final = Gfit_withMinFreeLysError;
            end
        end
        if Gfit_final(end) == 0; Gfit_final(end)  =1e-32; end;
        
        %calculating the residual error
        if Setting == 3
            [Opts,~,resid,~,~,~,J]  = lsqnonlin(@GO_fixLys_lsqnonlin2,[log(2)./Gfit_final],lb,ub,opts2, data.t, data.SILAC_data_temp,  data.Conc_temp, Setting, OptiResStep1.gama_Lys_best);
            Ci                      = nlparci(Opts,resid,'jacobian',J,'alpha',.05);
            [t,Lys_P_simu]          = ode15s(@(t,Lys_P)PT_ODE_fixLys(t,Lys_P,[log(2)./Opts],data.Conc_temp, OptiResStep1.gama_Lys_best),data.t,Lys_P_init);
            Prot_error              = (nansum((data.SILAC_data_temp(:,2:end) - Lys_P_simu(:,2:end-1)).^2));
            Glob_fit_Prot(data.se(i)+1:data.se(i+1),:) = [Opts(1:end-1)',Ci(1:end-1,:),Prot_error'];
        elseif Setting == 2
            [Opts,~,resid,~,~,~,J]  = lsqnonlin(@GO_fixLys_lsqnonlin2,[log(2)./Gfit_final(1:end-1) Gfit_final(end)],lb,ub,opts2, data.t, data.SILAC_data_temp,  data.Conc_temp, Setting, OptiResStep1.gama_Lys_best);
            Ci                      = nlparci(Opts,resid,'jacobian',J,'alpha',.05);
            [t,Lys_P_simu]          = ode15s(@(t,Lys_P)PT_ODE_Ratio_fixLys(t,Lys_P,[log(2)./Opts], OptiResStep1.gama_Lys_best),data.t,Lys_P_init);
            Prot_error              = (nansum((data.SILAC_data_temp(:,2:end) - Lys_P_simu(:,2:end)).^2));
            Glob_fit_Prot(data.se(i)+1:data.se(i+1),:) = [Opts(1:end-1)',Ci(1:end-1,:),Prot_error'];
       elseif Setting == 1
            [Opts,~,resid,~,~,~,J]  = lsqnonlin(@GO_fixLys_lsqnonlin2,[log(2)./Gfit_final(1:end-1) Gfit_final(end)],lb,ub,opts2, data.t, data.SILAC_data_temp,  data.Conc_temp, Setting, log(2)/OptiResStep1.gama_Lys_best);
            Ci                      = nlparci(Opts,resid,'jacobian',J,'alpha',.05);
            Lys_P_init              = ones(1,number_param);
            [t,Lys_P_simu]          = ode15s(@(t,Lys_P)PT_ODE_Ratio_fixLys(t,Lys_P,[log(2)./Opts(1:end-1) Opts(end)], OptiResStep1.gama_Lys_best),data.t,Lys_P_init);
            Prot_error              = (nansum((data.SILAC_data_temp - Lys_P_simu(:,2:end)).^2));
            Glob_fit_Prot(data.se(i)+1:data.se(i+1),:) = [Opts(1:end-1)',Ci(1:end-1,:),Prot_error'];
        end
    end
    if Setting == 3
        synthesis_rate              = (data.ProtConc)'.* (log(2)./Glob_fit_Prot(:,1));
        perce_Frac_synthesis_rate   = (synthesis_rate./data.ProtConc')*100;
        Gfit_tab                    = array2table([ data.SILAC_data', Glob_fit_Prot,  synthesis_rate, perce_Frac_synthesis_rate, data.ProtConc' ],'VariableNames',{'day0','day4','day8','day16','day32', 'HalfLife_in_days', 'HalfLife_CI_1', 'HalfLife_CI_2', 'residual_error', 'synthesis_rate', 'Perce_Frac_synthesis_rate', 'protein_conc'});
        writetable([data.protInfo, Gfit_tab],parameters.out_file, 'Sheet','Setting3');
    elseif Setting == 2
        Gfit_tab                    = array2table([ data.SILAC_data',Glob_fit_Prot],'VariableNames',{'day0','day4','day8','day16','day32', 'HalfLife_in_days', 'HalfLife_CI_1', 'HalfLife_CI_2', 'residual_error' });
        writetable([data.protInfo, Gfit_tab],parameters.out_file, 'Sheet','Setting2');
   elseif Setting == 1
        Gfit_tab                    = array2table( [data.SILAC_data', Glob_fit_Prot],'VariableNames',{'day0','day4','day8','day16','day32', 'HalfLife_in_days', 'HalfLife_CI_1', 'HalfLife_CI_2', 'residual_error' });
        writetable([data.protInfo,Gfit_tab],parameters.out_file, 'Sheet','Setting1');
    end

end

