clear all;
close all;
% Script that runs D-ADMM for BPDN with row partition:
%
%          minimize    0.5*||A*x - b||^2 + beta*||x||_1           (1)
%             x
%
% where x is the variable and ||.||_1 is the L1 norm. Row partition
% (VP) means that the matrix A and the vector b are partitioned as:
%
%               [    A1    ]              [b1]
%               [    A2    ]              [b2]
%          A =  [   ...    ]          b = [..]
%               [    AP    ]              [bP]
%
% and node p in the network only knows Ap and bp. We use a network provided
% in the file Nets_50_nodes.mat;

% =========================================================================
% Directories

% direct_current = pwd;                                      % Current
% direct_networks = '../../GenerateData/Networks';           % Networks
% % Compressed Sensing Data
% direct_data = '../../GenerateData/ProblemData/CompressedSensing';
% direct_DADMM = '../';                                      % D-ADMM
clear all;
direct_current = pwd;                                      % Current
direct_networks = '/home/tk12098/Documents/MATLAB/DADMM_paper_Code/GenerateData/Networks';           % Networks
% Compressed Sensing Data
direct_data = '/home/tk12098/Documents/MATLAB/DADMM_paper_Code/GenerateData/ProblemData/CompressedSensing';
direct_DADMM = '/home/tk12098/Documents/MATLAB/DADMM_paper_Code/D-ADMM';         
% =========================================================================


% =========================================================================
% Selecting the network

cd(direct_networks);
load Nets_50_nodes.mat;     % File with randomly generated networks
cd(direct_current);

% Select the network number: 1 to 7
net_num = 4;

Adj = Networks{net_num}.Adj;                   % Adjacency matrix
partition_colors = Networks{net_num}.Partition;% Color partition of network

P = length(Adj);                               % Number of nodes

% Construct the cell neighbors, where neighbors{p} is a vector with the
% neighbors of node p
neighbors = cell(P,1);

for p = 1 : P
    neighbors{p} = find(Adj(p,:));
end

% Create struct with network information
vars_network = struct('P', {P}, ...
    'neighbors', {neighbors}, ...
    'partition_colors', {partition_colors} ...
    );
% =========================================================================


% =========================================================================
% Selecting the data

% We use the Sparco toolbox: http://www.cs.ubc.ca/labs/scl/sparco/ or our
% own generated data (Id = 0)

Id = 0;

beta = 2;                                   

% cd(direct_data);
% if Id == 0        % Gaussian data
%     load GaussianData.mat;
%     [m, n] = size(A_BP);
% else
%     Prob = generateProblem(Id);
%     A_BP_aux = classOp(Prob.A);         % (Almost) explicit matrix A_BP
%     b = Prob.b;                         % Vector b
%     [m, n] = size(A_BP_aux);
%     
%     % Get the explicit matrix A_BP (in double format)
%     A_BP = zeros(m, n);
%     for i = 1 : m
%         ei = zeros(m,1);
%         ei(i) = 1;
%         A_BP(i,:) = (A_BP_aux'*ei)';
%     end
%     clear A_BP_aux;
% end
% cd(direct_current);

n=200;
m=50;
L=n;

positions = randi(L,[1,5]);%generate random spikes for signal

Tx_psd = zeros(1,L); %Tx PSD
Tx_psd(positions) = 1;
Eb_N0_dB = [10];
runs = 10;
[r,c] = size(Eb_N0_dB);

mse_admm_av = zeros(1,c);
mse_soln_av = zeros(1,c);

mse_admm = zeros(1,runs);
mse_soln = zeros(1,runs);

S = randn(m,L);
h = exprnd(0.15);
H = diag(h);
A_BP = S;
sigma = 10^(-Eb_N0_dB\20);
eta = randn(1,m)/m;
noise_sum = sum(eta);
b = A_BP*Tx_psd' + sigma*eta';

% For the groundtruth, we use the spgl1 solver

solution = spgl1(A_BP, b, 0, 0.0001, []);

fprintf('||A_BP*solution-b|| = %E\n', norm(A_BP*solution-b));
fprintf('norm(solution,1) = %E\n', norm(solution,1));

% Check if matrix partition is possible (all blocks with same size)
if mod(m,P) ~= 0
    error('m divided by P must be integer');
end
m_p = m/P;                         % Number of rows of A each node stores
                                   

% Create struct with problem data used in 'minimize_quad_prog_plus_l1_BB'
vars_prob = struct('handler', @BPDN_RP_Solver,...
    'handler_GPSR', @GPSR_BB, ...
    'A_BPDN', {A_BP}, ...
    'b_BPDN', {b}, ...
    'm_p', {m_p}, ...
    'P', {P}, ...
    'beta', {20} ...
    );
% =========================================================================

% =========================================================================
% Execute D-ADMM

% Optional input
 ops = struct('rho', {0.05}, ...
     'max_iter', {3000}, ...
     'x_opt', {solution}, ...
     'eps_opt', {1e-2}, ...
     'turn_off_eps', {0}....
 );

cd(direct_DADMM);
tic
[X, Z, vars_prob, ops_out] = DADMM(n, vars_prob, vars_network, ops);
toc
cd(direct_current);
% =========================================================================

% =========================================================================
% Print results

iterations = ops_out.iterations;
stop_crit = ops_out.stop_crit;
error_iterations_x = ops_out.error_iterations_x;
error_iterations_z = ops_out.error_iterations_z;
iter_for_errors = ops_out.iter_for_errors;

fprintf('norm(A*X{1} - b)/norm(b) = %f\n',norm(A_BP*X{1} - b)/norm(b));
fprintf('||X{1}||_1 = %f\n',norm(X{1},1));
fprintf('||X{1} - solutionl||/||solution|| = %f\n',norm(X{1}-solution)/norm(solution));
fprintf('Number of iterations = %d\n', iterations);
fprintf('stop_crit = %s\n', stop_crit);
fprintf('iter_for_errors = \n');
num_rows = size(iter_for_errors, 1);
for i_g = 1 : num_rows
    fprintf('%E    %d\n', iter_for_errors(i_g,1), iter_for_errors(i_g,2));
end

figure;clf;
semilogy(1:iterations,error_iterations_x(1:iterations), 'b');
title('error\_{iterations_x}');

figure;clf;
semilogy(1:iterations,error_iterations_z(1:iterations), 'b');
title('error\_{iterations_z}');


figure;
plot(X{1});

figure;
plot(Z{1})

figure;
plot(Tx_psd);
% =========================================================================






