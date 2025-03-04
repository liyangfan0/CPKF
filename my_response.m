function [pos,particle_S1,particle_S2,mu,Sigma,flag,F]=my_response(mu,Sigma,Q,R,A,C,particle_S1,particle_S2,pos,p,im,bg_area,area_resize_factor,w2c,hann_window,hf_num_hog,hf_num_cn,hf_den_hog,hf_den_cn,bg_hist,fg_hist)
%% TESTING step
% extract patch of size bg_area and resize to norm_bg_area
im_patch_cf = getSubwindow(im, pos, p.norm_bg_area, bg_area);
pwp_search_area = round(p.norm_pwp_search_area / area_resize_factor);
% extract patch of size pwp_search_area and resize to norm_pwp_search_area
im_patch_pwp = getSubwindow(im, pos, p.norm_pwp_search_area, pwp_search_area);
% compute feature map
xt = getFeatureMap(im_patch_cf, p.feature_type, p.cf_response_size, p.hog_cell_size,w2c);

% apply Hann window
xt_windowed = bsxfun(@times, hann_window, xt);

% compute FFT
xtf = fft2(xt_windowed);
xtf_hog=xtf(:,:,1:28);
xtf_cn=xtf(:,:,29:38);
% Correlation between filter and test patch gives the response
% Solve diagonal system per pixel.
if p.den_per_channel
    hf_hog = hf_num_hog ./ (hf_den_hog + p.lambda);
    hf_cn = hf_num_cn ./ (hf_den_cn + p.lambda);
else
    hf_hog = bsxfun(@rdivide, hf_num_hog, sum(hf_den_hog, 3)+p.lambda);
    hf_cn = bsxfun(@rdivide, hf_num_cn, sum(hf_den_cn, 3)+p.lambda);
end
response_cf_hog = ensure_real(ifft2(sum(conj(hf_hog) .* xtf_hog, 3)));
response_cf_cn = ensure_real(ifft2(sum(conj(hf_cn) .* xtf_cn, 3)));

% Crop square search region (in feature pixels).
response_cf_hog = cropFilterResponse(response_cf_hog, ...
    floor_odd(p.norm_delta_area / p.hog_cell_size));
response_cf_cn = cropFilterResponse(response_cf_cn, ...
    floor_odd(p.norm_delta_area / p.hog_cell_size));
if p.hog_cell_size > 1
    % Scale up to match center likelihood resolution.
    response_cf_hog = mexResize(response_cf_hog, p.norm_delta_area,'auto');
    response_cf_cn = mexResize(response_cf_cn, p.norm_delta_area,'auto');
end

[likelihood_map] = getColourMap(im_patch_pwp, bg_hist, fg_hist, p.n_bins, p.grayscale_sequence);
% (TODO) in theory it should be at 0.5 (unseen colors shoud have max entropy)
likelihood_map(isnan(likelihood_map)) = 0;

% each pixel of response_pwp loosely represents the likelihood that
% the target (of size norm_target_sz) is centred on it
response_pwp = getCenterLikelihood(likelihood_map, p.norm_target_sz);

%% ESTIMATION
response = mergeResponses(response_cf_hog,response_cf_cn,response_pwp, p.merge_factor, p.merge_method);
[row, col] = find(response == max(response(:)), 1);

center = (1+p.norm_delta_area) / 2;

pos = pos + ([row, col] - center) / area_resize_factor;
 %根据response_cf_hog求两个置信度
APCE_value=APCE(response_cf_hog);

Fmax=max(response_cf_hog(:));
particle_S1=[particle_S1,APCE_value];
particle_S2=[particle_S2,Fmax];

flag=flag_count(particle_S1,particle_S2);
%%%%%%%%%%%%%%
if flag==2

     [mu_bar, Sigma_bar] = kalmanPredict(mu, Sigma, A, Q);
     mu=mu_bar;

     pos=mu(1:2)'; 

else

    [mu, Sigma]=kalman(mu,Sigma,pos',Q,R,A,C);    
end
F=max(response(:));
%F=max(response_cf_hog(:));
end
% Reimplementation of Hann window (in case signal processing toolbox is missing)
function H = myHann(X)
    H = .5*(1 - cos(2*pi*(0:X-1)'/(X-1)));
end

% We want odd regions so that the central pixel can be exact
function y = floor_odd(x)
    y = 2*floor((x-1) / 2) + 1;
end

function y = ensure_real(x)
    assert(norm(imag(x(:))) <= 1e-5 * norm(real(x(:))));
    y = real(x);
end