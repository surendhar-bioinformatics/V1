function [] = Prot_turnover_v1(data,parameters)
%program to study the protein turnover kinetics. version 1.0.0
 
%read SILAC data 
size_Protein_data = size(data.SILAC_data,2);
fun_deg = @(b,tspan) exp(-b*tspan); 
for i =1:size_Protein_data
    Pdata_temp = data.SILAC_data(:,i);
	non_NaN_index_of_Pdata_temp = find(~isnan(Pdata_temp));
	Pdata_temp = Pdata_temp(non_NaN_index_of_Pdata_temp);
    rng default % For reproducibility
	ExpDegRate_temp = fminsearch(@(b) norm(Pdata_temp - fun_deg(b,data.t(non_NaN_index_of_Pdata_temp))), rand(1,1)) ;
	apparent_half_lives(i) = ExpDegRate_temp;
end
apparent_half_lives = transpose(log(2)./apparent_half_lives);
[~, idx] = sort(apparent_half_lives);
data.SILAC_data = data.SILAC_data(:,idx); 
data.ProtConc = data.ProtConc(:,idx);
data.protInfo = data.protInfo(idx, :); 

data.SILAC_data2 = data.SILAC_data(:, (sum(~isnan(data.SILAC_data)) > 4));
data.protInfo2 = data.protInfo((sum(~isnan(data.SILAC_data)) > 4),:);
data.ProtConc2 = data.ProtConc(:, (sum(~isnan(data.SILAC_data)) > 4));

% define Bin_size and Bin#
if parameters.Num_prot_to_fit < parameters.prot_per_fit
    Bin_size = parameters.Num_prot_to_fit;
else
    Bin_size = parameters.prot_per_fit;
end

Bins = ceil(size_Protein_data/Bin_size);
indices = ([0:Bin_size-1]*Bins)+1;
indices_0 = indices;
for i = 1:Bins-1
    indices = [indices (indices_0+i)];
end
indices(indices > size_Protein_data) = [];
data.SILAC_data = data.SILAC_data(:,indices); 
data.ProtConc = data.ProtConc(:,indices);
data.protInfo = data.protInfo(indices, :); 

data.SILAC_data = data.SILAC_data(:, 1:parameters.Num_prot_to_fit); 
data.ProtConc = data.ProtConc(:, 1:parameters.Num_prot_to_fit);
data.protInfo = data.protInfo(1:parameters.Num_prot_to_fit,:); 
size_Protein_data = size(data.SILAC_data,2);
%creating an array with bin size
data.se = [0];
for i = 1:floor(size_Protein_data/parameters.prot_per_fit)
    data.se(i+1) = i*parameters.prot_per_fit;
end
if (mod(size_Protein_data,parameters.prot_per_fit) > 0)  && (mod(size_Protein_data,parameters.prot_per_fit) > 50)
    data.se(end+1) = size_Protein_data; 
elseif (mod(size_Protein_data,parameters.prot_per_fit) > 0)  && (mod(size_Protein_data,parameters.prot_per_fit) < 51) && (length(data.se) >1)
    data.se(end) = size_Protein_data; 
elseif (mod(size_Protein_data,parameters.prot_per_fit) > 0)  && (mod(size_Protein_data,parameters.prot_per_fit) < 51) && (length(data.se) == 1)
    data.se(end+1) = size_Protein_data; 
end

%% create araay and bin for selcted protein with all time points 
size_Protein_data2 = size(data.SILAC_data2,2);
% define Bin_size and Bin#
if parameters.Num_prot_to_fit < parameters.prot_per_fit
    Bin_size = parameters.Num_prot_to_fit;
else
    Bin_size = parameters.prot_per_fit;
end

Bins = ceil(size_Protein_data2/Bin_size);
indices = ([0:Bin_size-1]*Bins)+1;
indices_0 = indices;
for i = 1:Bins-1
    indices = [indices (indices_0+i)];
end
indices(indices > size_Protein_data2) = [];
data.SILAC_data2 = data.SILAC_data2(:,indices); 
data.ProtConc2 = data.ProtConc2(:,indices);
data.protInfo2 = data.protInfo2(indices, :);

if parameters.Num_prot_to_fit < size_Protein_data2
    data.SILAC_data2 = data.SILAC_data2(:, 1:parameters.Num_prot_to_fit); 
    data.ProtConc2 = data.ProtConc2(:, 1:parameters.Num_prot_to_fit);
    data.protInfo2 = data.protInfo2(1:parameters.Num_prot_to_fit, :); 
end
size_Protein_data2 = size(data.SILAC_data2,2);
%creating an array with bin size
data.se2 = [0];
for i = 1:floor(size_Protein_data2/parameters.prot_per_fit)
    data.se2(i+1) = i*parameters.prot_per_fit;
end
if (mod(size_Protein_data2,parameters.prot_per_fit) > 0)  && (mod(size_Protein_data2,parameters.prot_per_fit) > 50)
    data.se2(end+1) = size_Protein_data2; 
elseif (mod(size_Protein_data2,parameters.prot_per_fit) > 0)  && (mod(size_Protein_data2,parameters.prot_per_fit) < 51) && (length(data.se2) >1)
    data.se2(end) = size_Protein_data2; 
elseif (mod(size_Protein_data2,parameters.prot_per_fit) > 0)  && (mod(size_Protein_data2,parameters.prot_per_fit) < 51) && (length(data.se2) == 1)
    data.se2(end+1) = size_Protein_data2; 
end
%
if length(data.se2) > 3
    data.se2 = data.se2(1:3);
end 

rng default % For reproducibility
data.Ansatz_          = rand(11,size_Protein_data+2);
tic

%% Calculate the half-lives with different settings

Glob_fit_Prot = [];
if parameters.setting3 == 1
    % Fitting/optimizing data with all time points to get the Lys degredation rate and ratio between avearage protein-bound Lys and free lys
    OptiResStep1 = gama_Lys(data,parameters,3);    %keyboard
    Glob_fit_Prot_setting3 = OptiResStep1.prot_deg_rate;
    if (data.se2(end) ~= data.se(end)) || (length(data.se2) ~= 2)
        Glob_fit_Prot_setting3 = gama_Prot(data,parameters,OptiResStep1, 3);
    end
    Glob_fit_Prot = [Glob_fit_Prot Glob_fit_Prot_setting3(:,1)];
    median_half_Lives_setting3 = median(Glob_fit_Prot_setting3(:,1))
end
if parameters.setting2 == 1
    % Fitting/optimizing data with all time points to get the Lys degredation rate and ratio between avearage protein-bound Lys and free lys
    OptiResStep1 = gama_Lys(data,parameters,2);
    Glob_fit_Prot_setting2 = OptiResStep1.prot_deg_rate;
    if (data.se2(end) ~= data.se(end)) || (length(data.se2) ~= 2)
        Glob_fit_Prot_setting2 = gama_Prot(data,parameters,OptiResStep1, 2);
    end
    Glob_fit_Prot = [Glob_fit_Prot Glob_fit_Prot_setting2(:,1)];
    median_half_Lives_setting2 = median(Glob_fit_Prot_setting2(:,1))

end
if parameters.setting1 == 1
    % Fitting/optimizing data with all time points to get the Lys degredation rate and ratio between avearage protein-bound Lys and free lys
    OptiResStep1 = gama_Lys(data,parameters,1); 
    Glob_fit_Prot_setting1 = OptiResStep1.prot_deg_rate;
    if (data.se2(end) ~= data.se(end)) || (length(data.se2) ~= 2)
        Glob_fit_Prot_setting1 = gama_Prot(data,parameters,OptiResStep1,1);
    end
    Glob_fit_Prot = [Glob_fit_Prot Glob_fit_Prot_setting1(:,1)];
    median_half_Lives_setting1 = median(Glob_fit_Prot_setting1(:,1))
end

fprintf('\n *****  Completed exporting half-live to excel file ; Now the Program is complete *******\n\n')
end

