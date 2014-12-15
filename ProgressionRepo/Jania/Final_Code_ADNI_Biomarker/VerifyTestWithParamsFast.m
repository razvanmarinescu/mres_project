function [parm_struct] = VerifyTestWithParamsFast(data_controls, data_patients, parm_mcmc)

%% Initialization 
[nr_events, nr_pat] = size(data_patients);
nr_gradient_ascent = parm_mcmc.nr_gradient_ascent;
nr_it_gradient_ascent = parm_mcmc.nr_it_gradient_ascent;
nr_it_burnin = parm_mcmc.nr_it_burnin;
nr_it_mcmc = parm_mcmc.nr_it_mcmc;
nr_it_check_p_false = parm_mcmc.nr_it_check_p_false;
range_p_false = parm_mcmc.range_p_false;
std_p_false = parm_mcmc.std_p_false;
flag_sum = parm_mcmc.flag_sum;
accept_count=0;


thisMean_noevent_mcmc=zeros(nr_it_mcmc,1);
thisMean_event_mcmc=zeros(nr_it_mcmc,1);
thisCov_noevent_mcmc=zeros(nr_it_mcmc,1);
thisCov_event_mcmc=zeros(nr_it_mcmc,1);

thisMean_noevent_burn=zeros(nr_it_burnin,1);
thisMean_event_burn=zeros(nr_it_burnin,1);
thisCov_noevent_burn=zeros(nr_it_burnin,1);
thisCov_event_burn=zeros(nr_it_burnin,1);


pMNE=zeros(nr_it_mcmc,1);
pME=zeros(nr_it_mcmc,1);
pCNE=zeros(nr_it_mcmc,1);
pCE=zeros(nr_it_mcmc,1);

loglikeNew=zeros(nr_it_mcmc,1);
loglikeNewWop=zeros(nr_it_mcmc,1);  %log likelihood without prior over parameters

interval_display = parm_mcmc.interval_display;
it_vec = 1:interval_display:(nr_it_mcmc + nr_it_burnin);
data_tot=[data_controls data_patients];
[nr_events, nr_subj]=size(data_tot);

%% Get an initial estimate of the means and variances from the data
version_likelihood = 13;  %version_likelihood==13 is the same as 8 but with a different GMM package
nAttempts=5;
threshold_flag=0;
[likelihood_events_est, gmix_struct_est] = ...
    EBDPComputeLikelihood(data_patients', data_controls', version_likelihood,threshold_flag,nAttempts);


%%  Evaluate the priors for current Mu and sigma
for roi=1:nr_events
    
    %% set means using mixGaussFit
    thisMean_noevent=gmix_struct_est.gmix_controls{roi}.mean;
    thisMean_event=gmix_struct_est.gmix_patients{roi}.mean;
    thisCov_noevent=gmix_struct_est.gmix_controls{roi}.cov;
    thisCov_event=gmix_struct_est.gmix_patients{roi}.cov;
    
    %%        %set arbitrary means
    %         thisMean_noevent=0.2;
    %         thisMean_event=-5;
    %         thisCov_noevent=1;
    %         thisCov_event=6.5;
    %
    
    %% set the hyperparameters of the priors over Mu and Sigma
    
    %set the prior normal distribution centered over current mean
    init_mean_noevent=thisMean_noevent;
    init_mean_event=thisMean_event;
    init_cov_noevent=thisCov_noevent;
    init_cov_event=thisCov_event;
    
    
    %% set the sigma for event and noevent based on minimum and maximum
    % value of the data_atient and data_control distributions separately
    
    %set the sigma of the prior normal distribution such that
    %min and max values of current biomarker are within + / - 3sigma
    minC=min(data_controls);
    maxC=max(data_controls);
    sigmaMin=(init_mean_noevent-minC)/3;
    sigmaMax=(maxC-init_mean_noevent)/3;
    prior_sigma_noevent=max([sigmaMin,sigmaMax]);
    
    minP=min(data_patients);
    maxP=max(data_patients);
    sigmaMin=(init_mean_event-minP)/3;
    sigmaMax=(maxP-init_mean_event)/3;
    prior_sigma_event=max([sigmaMin,sigmaMax]);
    
    %set the prior over the mean to be a Gaussian Distribution with the
    %above define parametes
    prior_thisMean_noevent=normpdf(thisMean_noevent,init_mean_noevent,prior_sigma_noevent);
    prior_thisMean_event=normpdf(thisMean_event,init_mean_event,prior_sigma_event);
    
    %set the prior over the variance to be a uniform prior
    prior_thisCov_noevent=unifpdf(thisCov_noevent,0,1e10);
    prior_thisCov_event=unifpdf(thisCov_event,0,1e10);
    
    
    
    %% Visualize the likelihood and the prior distributions
    %close all
    %plot for no-event
    like_noevent_dist=normpdf(data_controls,thisMean_noevent,sqrt(thisCov_noevent));
    xmu0=linspace(min(data_controls),max(data_controls));
    prior_dist_mean_noevent=normpdf(xmu0,init_mean_noevent,prior_sigma_noevent);
    xsig0=[0.1:0.1:10];
    prior_dist_sigma_noevent=unifpdf(xsig0,0,1e10);
    cum_dist_prior_sigma_noevent=unifcdf(xsig0,0,1e10);
    
    
    figure
    subplot(1,4,1);plot(data_controls,like_noevent_dist,'g.');title('Likelihood Dist No-event');
    hold on
    subplot(1,4,2);plot(xmu0,prior_dist_mean_noevent,'b.');title('Prior Dist over Mean')
    subplot(1,4,3);plot(xsig0,prior_dist_sigma_noevent,'m.');title('Prior Dist over Sigma');
    subplot(1,4,4);plot(xsig0,cum_dist_prior_sigma_noevent,'m.-');title('Cumulative Dist Prior Sigma');
    set(gcf,'Color',[ 1 1 1]);
    
    %plot for event
    figure
    like_event_dist=normpdf(data_patients,thisMean_event,sqrt(thisCov_event));
    xmu0=linspace(min(data_patients),max(data_patients));
    prior_dist_mean_event=normpdf(xmu0,init_mean_event,prior_sigma_event);
    xsig0=[0.1:0.1:10];
    prior_dist_sigma_event=unifpdf(xsig0,0,1e10);
    cum_dist_prior_sigma_event=unifcdf(xsig0,0,1e10);
    
    subplot(1,4,1);plot(data_patients,like_event_dist,'r.');title('Likelihood Dist Event');
    hold on
    subplot(1,4,2);plot(xmu0,prior_dist_mean_event,'b.');title('Prior Dist over Mean')
    subplot(1,4,3);plot(xsig0,prior_dist_sigma_event,'m.');title('Prior Dist over Sigma');
    subplot(1,4,4);plot(xsig0,cum_dist_prior_sigma_event,'m.-');title('Cumulative Dist Prior Sigma');
    set(gcf,'Color',[ 1 1 1]);
    
    
    % compare the estimated distribution vs true distribution
    figure
    p_controls = like_noevent_dist;
    p_patients = like_event_dist;
    [hist_c, x_c] = ksdensity(data_controls);
    [hist_p, x_p] = ksdensity(data_patients);
    
    subplot(121), hold on
    plot(x_c, hist_c, 'g');
    plot(x_p, hist_p, 'r');
    legend('No Event','Event');
    title('True Distributions');
    subplot(122), hold on
    plot(data_controls, p_controls, 'g.')
    plot(data_patients, p_patients, 'r.');
    set(gcf,'Color',[ 1 1 1]);
    title('Estimated Distributions');
    legend('No Event','Event');
    
end


flag_sum=2; % this should always be 2


%%  Now MCMC initialization
log_likelihood_mcmc = zeros(nr_it_mcmc, 1);
log_likelihood_burn=zeros(nr_it_burnin,1);


weight_noevent=0.5;  % set fixed weights for the gaussian components
weight_event=0.5;

%Note I replace the log_likelihood_current of the gradient ascent with that
%of when also including the prior over parameters

%find the current likelihood event no event
likelihood_events(:, 1) = getGaussProb(data_tot,thisMean_noevent,sqrt(thisCov_noevent));
likelihood_events(:, 2) = getGaussProb(data_tot,thisMean_event,sqrt(thisCov_event));


likelihood_data= likelihood_events(:, 1).*weight_noevent*prior_thisMean_noevent*prior_thisCov_noevent+ ...
    likelihood_events(:,2).*weight_event*prior_thisMean_event*prior_thisCov_event;
log_likelihood_current=sum(log(likelihood_data));

%for debugging purposed also find the likelihood of the data without prior
%over parameters
likelihood_data_wop= likelihood_events(:, 1).*weight_noevent+ ...
    likelihood_events(:,2).*weight_event;
log_likelihood_current_wop=sum(log(likelihood_data_wop));


log_likelihood_max = log_likelihood_current;
thisMean_noevent_max=thisMean_noevent;
thisMean_event_max=thisMean_event;
thisCov_noevent_max= thisCov_noevent;
thisCov_event_max= thisCov_event;



log_likelihood_max_wop = log_likelihood_current_wop;
thisMean_noevent_max_wop=thisMean_noevent;
thisMean_event_max_wop=thisMean_event;
thisCov_noevent_max_wop= thisCov_noevent;
thisCov_event_max_wop= thisCov_event;


change_step_muNE=0.035;
change_step_muE=0.035;
change_step_sigNE=0.035;
change_step_sigE=0.035;


min_sigma=0.09;

%calculate a proposal distribution in this case based on the variance of
%each of the data patient and data control
sigma_event=std(data_patients)^2;
if sigma_event<min_sigma
    sigma_event=min_sigma;
end
sigma_noevent=std(data_controls)^2;
if sigma_noevent<min_sigma
    sigma_noevent=min_sigma;
end


thisMean_noevent_current=thisMean_noevent;
thisMean_event_current=thisMean_event;
thisCov_noevent_current= thisCov_noevent;
thisCov_event_current= thisCov_event;

thisMean_noevent_new=thisMean_noevent_current;
thisMean_event_new=thisMean_event_current;
thisCov_noevent_new= thisCov_noevent_current;
thisCov_event_new= thisCov_event_current;


%% start the MCMC
for it_mcmc = 1:(nr_it_burnin + nr_it_mcmc),
    
    % varying the means and the variances
    for roi=1:nr_events
        
        % Use a separate proposal dists for event and no event
        %to sample new parameters from already accepted parameters
        thisMean_noevent_new=thisMean_noevent_current+sigma_noevent*change_step_muNE*randn;
        thisMean_event_new=thisMean_event_current+ sigma_event*change_step_muE*randn;
        thisCov_noevent_new=thisCov_noevent_current+ sigma_noevent*change_step_sigNE*randn;
        thisCov_event_new=thisCov_event_current+ sigma_event*change_step_sigE*randn;
        
        
        
        % Calculate the prior for the new parameters
        prior_thisMean_noevent_new=normpdf(thisMean_noevent_new,init_mean_noevent,prior_sigma_noevent);
        prior_thisMean_event_new=normpdf(thisMean_event_new,init_mean_event,prior_sigma_event);
        prior_thisCov_noevent_new=unifpdf(thisCov_noevent_new,0,1e10);
        prior_thisCov_event_new=unifpdf(thisCov_event_new,0,1e10);
        
        
        
        % constrain the Mean Event to always be smaller than Mean No-event
        if thisMean_event_new>thisMean_noevent_new
            prior_thisMean_noevent_new=0;
            prior_thisMean_event_new=0;
        end
        
        
        %find the current likelihood event no event
        likelihood_events_new(:,1) = getGaussProb(data_tot,thisMean_noevent_new,sqrt(thisCov_noevent_new));
        likelihood_events_new(:,2) = getGaussProb(data_tot,thisMean_event_new,sqrt(thisCov_event_new));
        
        
    end
    
    %Compute the new likelihood after swapping some events and changing the
    %mu and sigma
    
    likelihood_data_new= likelihood_events_new(:, 1).*weight_noevent*prior_thisMean_noevent_new*prior_thisCov_noevent_new+ ...
        likelihood_events_new(:,2).*weight_event*prior_thisMean_event_new*prior_thisCov_event_new;
    log_likelihood_new=sum(log(likelihood_data_new));
    
    
    
    %for debugging purposed also find the likelihood of the data without prior
    %over parameters
    likelihood_data_new_wop= likelihood_events_new(:, 1).*weight_noevent+ ...
        likelihood_events_new(:,2).*weight_event;
    log_likelihood_new_wop=sum(log(likelihood_data_new_wop));
    
    
    alpha= exp(log_likelihood_new - log_likelihood_current);
    u=rand;
    
    if alpha> u
        
        thisMean_noevent_current=thisMean_noevent_new;
        thisMean_event_current=thisMean_event_new;
        thisCov_noevent_current= thisCov_noevent_new;
        thisCov_event_current= thisCov_event_new;
        log_likelihood_current = log_likelihood_new;
        
        if it_mcmc > nr_it_burnin
            accept_count=accept_count+1;
        end
        
    end
    if log_likelihood_current > log_likelihood_max,
        
        thisMean_noevent_max=thisMean_noevent_current;
        thisMean_event_max=thisMean_event_current;
        thisCov_noevent_max= thisCov_noevent_current;
        thisCov_event_max= thisCov_event_current;
        log_likelihood_max = log_likelihood_current;
        
    end
    
    if log_likelihood_current_wop > log_likelihood_max_wop,
        
        thisMean_noevent_max_wop=thisMean_noevent_current;
        thisMean_event_max_wop=thisMean_event_current;
        thisCov_noevent_max_wop= thisCov_noevent_current;
        thisCov_event_max_wop= thisCov_event_current;
        log_likelihood_max_wop = log_likelihood_current_wop;
        
    end
    
    
    
    if it_mcmc > nr_it_burnin,
        
        
        thisMean_noevent_mcmc(it_mcmc-nr_it_burnin)=thisMean_noevent_current;
        thisMean_event_mcmc(it_mcmc-nr_it_burnin)=thisMean_event_current;
        thisCov_noevent_mcmc(it_mcmc-nr_it_burnin)= thisCov_noevent_current;
        thisCov_event_mcmc(it_mcmc-nr_it_burnin)= thisCov_event_current;
        log_likelihood_mcmc(it_mcmc-nr_it_burnin) = log_likelihood_current;
    else
        
        thisMean_noevent_burn(it_mcmc)=thisMean_noevent_current;
        thisMean_event_burn(it_mcmc)=thisMean_event_current;
        thisCov_noevent_burn(it_mcmc)= thisCov_noevent_current;
        thisCov_event_burn(it_mcmc)= thisCov_event_current;
        log_likelihood_burn(it_mcmc) = log_likelihood_current;
    end
    
    if find(it_vec == it_mcmc),
        
        if it_mcmc < nr_it_burnin,
            
            fprintf('burnin it: %d\n', it_mcmc)
            
        else
            
            fprintf('mcmc it: %d\n', it_mcmc-nr_it_burnin)
            
        end
        
    end
    
    
end % end MCMC iter


%% visualize the posterior over parameters i.e. the mcmc sampels
figure
subplot(2,2,1); plot([thisMean_noevent_burn; thisMean_noevent_mcmc]);title('Mean NoEvent');
hold on
subplot(2,2,2); plot([thisMean_event_burn; thisMean_event_mcmc]);title('Mean Event');
subplot(2,2,3); plot([thisCov_noevent_burn; thisCov_noevent_mcmc]);title('Variance NoEvent');
subplot(2,2,4); plot([thisCov_event_burn; thisCov_event_mcmc]);title('Variance Event');
set(gcf,'Color',[ 1 1 1]);


[mu_c, x_c] = ksdensity(thisMean_noevent_mcmc);
[mu_p, x_p] = ksdensity(thisMean_event_mcmc);
[var_c, v_c] = ksdensity(thisCov_noevent_mcmc);
[var_p, v_p] = ksdensity(thisCov_event_mcmc);
figure
subplot(1,2,1); plot(x_c,mu_c,'g');
hold on; plot(x_p,mu_p,'r');
subplot(1,2,2); plot(v_c,var_c,'g');
hold on; plot(v_p,var_p,'r');
set(gcf,'Color',[ 1 1 1]);

meanParamsMCMC=[mean(thisMean_noevent_mcmc) mean(thisMean_event_mcmc) mean(thisCov_noevent_mcmc) mean(thisCov_event_mcmc)]
varParamsMCMC=[var(thisMean_noevent_mcmc) var(thisMean_event_mcmc) var(thisCov_noevent_mcmc) var(thisCov_event_mcmc)]



parm_struct.log_likelihood_mcmc = log_likelihood_mcmc;
%parm_struct.p_false_max = p_false_max;
parm_struct.log_likelihood_max = log_likelihood_max;
%parm_struct.class_pat = class_pat;
parm_struct.thisMean_noevent_mcmc=thisMean_noevent_mcmc;
parm_struct.thisMean_event_mcmc=thisMean_event_mcmc;
parm_struct.thisCov_noevent_mcmc=thisCov_noevent_mcmc;
parm_struct.thisCov_event_mcmc=thisCov_event_mcmc;

parm_struct.log_likelihood_burn = log_likelihood_burn;
parm_struct.thisMean_noevent_burn=thisMean_noevent_burn;
parm_struct.thisMean_event_burn=thisMean_event_burn;
parm_struct.thisCov_noevent_burn=thisCov_noevent_burn;
parm_struct.thisCov_event_burn=thisCov_event_burn;

save(['verifyDataSimulationMCMC/VerifyMCMCResultWith' num2str(10) '-' num2str(log10(nr_it_mcmc)) 'Itr' num2str(change_step_muE) 'Steps.mat'],'parm_struct');
