function [] = sporadic_ebm()

load('alex_data/ADNIdata_Baseline.mat')

% ADNIdataBL raw data as received from the ADNI website
%EBMdataBL - pre-processed data for use in the EBM model
% EMBLdxBL - the level of impairment for each patient (1 - Cognitively normal, 2 - MCI 3 - AD)
% EBMevents - labels of the EBM events

[nr_patients, nr_biomarkers] = size(EBMdataBL)

control_indices = find(EBMdxBL == 1)
patient_indices = find(EBMdxBL > 1)

% pXgEnE(i,j,1) = p(x_ij | Ei) (patients)
% pXgEnE(i,j,2) = p(x_ij | not Ei) (controls)
pXgEnE = zeros(nr_patients, nr_biomarkers,2);

for biomk=1:nr_biomarkers
   control_levels = EBMdataBL(control_indices, biomk)
   patient_levels = EBMdataBL(patient_indices, biomk)
    
   mu_control = mean(control_levels);
   sigma_control = std(control_levels)^2;
   
   mu_patient = mean(patient_levels);
   sigma_patient = std(patient_levels)^2;
   
   %pXgEnE(:, biomk, 2) = normpdf(control_levels, mu_control, sigma_control);
   %pXgEnE(:, biomk, 1) = normpdf(patient_levels, mu_patient, sigma_patient);
   
   
   all_levels = EBMdataBL(:, biomk);
   % fit two gaussians on all the data

   [mu_mix, sigma_mix, pi_mix]  = ...
       em_mix(all_levels, mu_control, mu_patient, sigma_control, sigma_patient)
   

   minX = min(all_levels);
   maxX = max(all_levels);
   X = minX:(maxX - minX)/200:maxX;
   Y = eval_mix_gaussians(X, mu_mix, sigma_mix, pi_mix);
   
   %Y = Y .* max(Y)
   
   clf;
   [f1,x1] = hist(patient_levels);
   bar(x1,f1, 'FaceColor',[0.8,0.2,0.2]);
   %h = findobj(gca,'Type','patch');
   %h.FaceColor = [0.8 0.2 0.2];
   %h.EdgeColor = 'b';
   hold on
   [f2,x2] = hist(control_levels);
   bar(x2,f2,'b');
   %hist(control_levels);
   hold on
   plot(X, Y);

   %hist(control_levels,50)
   
end

end

function [mu, sigma, pi]  = ...
    em_mix(data, mu_control_init, mu_patient_init, max_sigma_control, max_sigma_patient)

% data is a 1d array of biomarker levels which is assumed to be generated
% from a mixture of 2 gaussian distributions

mu = [mu_control_init, mu_patient_init];
sigma = [max_sigma_control, max_sigma_patient];

sigma_max = sigma;

% pi_control is the weight of the control gaussian
% pi(1) - control pi(2) - patient
pi = [0.5 0.5];

N = length(data); 
K = 2;

assert(length(mu) == K && length(sigma) == K && length(pi) == K);

znk = zeros(N,K);
eval_matrix = zeros(N,K);

log_likely = inf;
thresh = 0.0001

iterations = 100;
%% keep updating until convergence
for iter=1:iterations
    
    % E-step
    for k=1:K
        znk(:,k) = pi(k) * normpdf(data, mu(k), sigma(k));
    end

    % normalise the znk rows
    for n=1:N
        znk(n,:) = znk(n,:) ./ sum(znk(n,:));
    end

    % M-step

    Nk = sum(znk);
    
    if(~all(Nk))
        break
    end
    
    for k=1:K

           
       mu(k) =  sum(znk(:,k) .* data) /Nk(k);
       sigma(k) = sum(znk(:,k) .* (data - mu(k)) .* (data - mu(k)) ) / Nk(k);

       % set the constraint that alex implemented in the paper: i.e. the sigma
       % of each distribution should not be greater than the sigma of the CN
       % and AD groups taken separately
       if (sigma(k) > sigma_max(k))
           display('constraint in place')
           sigma(k) = sigma_max(k);
       end
       
       pi = Nk / N;  
       
        % Evaluate the log_likelihood
        for k=1:K
            eval_matrix(:,k) = pi(k) * normpdf(data, mu(k), sigma(k));
        end

        sumK = sum(eval_matrix, 2);
        assert(length(sumK) == N);
        log_likely = sum(log(sumK))
        
        X = min(data):0.005:max(data);
        %hist(data,25)
        %hold on
        %plot(X, eval_mix_gaussians(X, mu, sigma, pi))

    end
    
    if(~all(sigma))
        break
    end
end
    

end

function Y = eval_mix_gaussians(X, mu, sigma, pi)
% X is a vector of data points
% mu is a vector of means
% sigma is a vector of std deviations

K = length(mu);
Y = zeros(size(X));

for k=1:K
   if (sigma(k) ~= 0) 
       Y = Y + pi(k) * normpdf(X, mu(k), sigma(k)); 
   end
end

end