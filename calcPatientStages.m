function stages = calcPatientStages(X, S, mu_mix, sigma_mix, pi_mix)

% modelled from equation (1), alex paper page 2567
% J - # patients
% I - # Events or disease stages
[J,I] = size(X);


[I2,~] = size(mu_mix);
[I3,~] = size(sigma_mix);

assert(I == I2 && I == I3);

%reorder the gaussian parameters according to the S ordering provided
mu_mix = mu_mix(S,:);
sigma_mix = sigma_mix(S,:);
% pi_mix = pi_mix(S,:);

%also reorder the dataset
X = X(:,S);

% x_{ij} biomarker i in subject j
% pXgE(i,j,1) = p (x_{ij} | E_i)      patients
% pXgE(i,j,2) = p (x_{ij} | not E_i)  controls
pXgE = zeros(I, J);
pXgnE = zeros(I, J);
% for each biomarker 
% mu_mix(:,1) - controls
% mu_mix(:,2) - patients
for biomk=1:I
%     pXgE(biomk,:) = pi_mix(biomk,2) * normpdf(X(:,biomk), mu_mix(biomk,2), sigma_mix(biomk,2));
%     pXgnE(biomk,:) = pi_mix(biomk,1) * normpdf(X(:,biomk), mu_mix(biomk,1), sigma_mix(biomk,1));
    pXgE(biomk,:) = normpdf(X(:,biomk), mu_mix(biomk,2), sigma_mix(biomk,2));
    pXgnE(biomk,:) = normpdf(X(:,biomk), mu_mix(biomk,1), sigma_mix(biomk,1));
    if(~all(pXgE(biomk,:)))
        display('pXgE is zero')
    end
end

pK = 1/J; % uniform prior that patient i is at stage k.


prod_pXgE = zeros(I+1,J);
% for each disease stage
for stage=0:I
    prod_pXgE(stage+1,:) = prod(pXgE(1:stage,:),1) .* prod(pXgnE(stage+1:I,:),1);
end

[~, stages] = max(prod_pXgE);

stages = stages - 1;

end