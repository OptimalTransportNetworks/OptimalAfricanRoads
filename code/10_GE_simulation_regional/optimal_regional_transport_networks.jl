
using DataFrames, CSV, LinearAlgebra, Statistics, StatsBase, Plots, NaNStatistics
using OptimalTransportNetworks

# Read Undirected Graph
graph_orig = CSV.read("data/transport_network/csv/graph_orig.csv", DataFrame)
graph_orig.add .= false
# Read Additional Links 
graph_add = CSV.read("data/transport_network/csv/graph_add.csv", DataFrame)
graph_add.add .= true
# Combining
graph = vcat(select(graph_orig, :add, :from, :to, :sp_distance, :distance, :duration, :ug_cost_km => :cost_per_km, :border_dist), 
             select(graph_add, :add, :from, :to, :sp_distance, :distance, :duration_100kmh => :duration, :cost_km => :cost_per_km, :border_dist))
histogram(graph.cost_per_km, bins=100)

# Adjusting 
graph.distance /= 1000    # Convert to km
graph.sp_distance /= 1000 # Convert to km
graph.border_dist /= 1000 # Convert to km
graph.duration /= 60      # Convert to hours
graph.cost_per_km /= 1e6  # Convert to millions
graph.total_cost = graph.cost_per_km .* graph.distance

n = maximum([maximum(graph.from), maximum(graph.to)])

# Create Adjacency Matrix
adj_matrix = falses(n, n)
for i in 1:size(graph, 1)
    adj_matrix[graph.from[i], graph.to[i]] = adj_matrix[graph.to[i], graph.from[i]] = true
end

# Read Nodes Data
nodes = CSV.read("data/transport_network/csv/graph_nodes.csv", DataFrame)
nodes.population /= 1000 # Convert to thousands
nodes.outflows /= 1000   # Adjust in line with population
describe(nodes)

# Create Infrastructure Matrix: Following Graff (2024) = average speed in km/h: length of route is accounted for in cost function
infra_matrix = zeros(n, n)
for i in 1:size(graph, 1)
    if graph.add[i]
        infra_matrix[graph.from[i], graph.to[i]] = infra_matrix[graph.to[i], graph.from[i]] = 0.0
    else
        speed = graph.distance[i] / graph.duration[i]
        infra_matrix[graph.from[i], graph.to[i]] = infra_matrix[graph.to[i], graph.from[i]] = speed
    end
end

# Create Iceberg Trade Cost Matrix: Following Graff (2024)
# graph.distance += graph.border_dist # uncomment to enable frictions
iceberg_matrix = zeros(n, n)
for i in 1:size(graph, 1)
    iceberg_matrix[graph.from[i], graph.to[i]] = iceberg_matrix[graph.to[i], graph.from[i]] = 0.1158826 * log(graph.distance[i] / 1.609)
end
iceberg_matrix[iceberg_matrix .< 0] .= 0

# Create Infrastructure Building Cost Matrix: Following Graff (2024)
infra_building_matrix = zeros(n, n)
for i in 1:size(graph, 1)
    infra_building_matrix[graph.from[i], graph.to[i]] = infra_building_matrix[graph.to[i], graph.from[i]] = graph.total_cost[i]
end

# Basic characteristics of the economy
population = nodes.population
population += (population .== 0) * 1e-6 # this is needed as ipopt crashes otherwise (need to have population > 0 always), so I add an infinitisimal person

# Productivity Matrix 
with_ports = true
productivity = zeros(n, 4)
if with_ports
    for i in 1:n
        if nodes.outflows[i] > 0
            ind = 4
            productivity[i, ind] = (37 * nodes.outflows[i]) / population[i] # Productivity of ports
        else
            ind = population[i] >= 1000 ? 3 : population[i] >= 200 ? 2 : 1
        end
        productivity[i, ind] += nodes.IWI[i] 
    end
else
    for i in 1:n
        ind = nodes.outflows[i] > 0 ? 4 : population[i] >= 1000 ? 3 : population[i] >= 200 ? 2 : 1
        productivity[i, ind] = nodes.IWI[i] 
    end
end

size(productivity)
extrema(productivity)
for i in 1:size(productivity, 2)
   println(extrema(productivity[:, i]))
end

J, N = size(productivity)

# Infrastructure Bounds
min_mask = infra_matrix                          
max_mask = max.(infra_matrix, adj_matrix .* 100)

# Cost of all Road Activities (162 billion)
K_inv = sum(infra_building_matrix) / 2 
# Total implied costs
infra_building_matrix ./= (max_mask - infra_matrix)
infra_building_matrix[isinf.(infra_building_matrix)] .= 0
infra_building_matrix[isnan.(infra_building_matrix)] .= 0
K_base = sum(infra_building_matrix .* infra_matrix) / 2 # Baseline budget = cost of existing infrastructure
# Now setting budget
K = (K_base + 50e3) * 2 # 50 billion USD'15 investment volume (*2 because symmetric)

K / sum(infra_building_matrix .* max_mask)
K / sum(infra_building_matrix .* min_mask)
if K > sum(infra_building_matrix .* max_mask)
    error("Infrastructure budget is too large for the network")
end

# Parameters
alpha = 0.7 # Spending share on traded goods in utility (curvature parameter)
gamma = 0.946 # F&S: 0.1 ; TG: 0.946; Parameter governing intensity of congestion in transport
beta = 1.2446 * gamma # F&S: 0.13 ; TG: 1.2446 * gamma; Parameter governing returns to scale in infrastructure investment
# gamma = beta^2/gamma # IRS case
sigma = 1.5 #5; # Elasticity of substitution parameter
a = 1 # F&S: 1; TG: 0.7; Returns to scale to labor in production function Zn * Ln^a
rho = 0 # inequality aversion: not possible to solve model if enabled (= 2) -> set alpha = 0.1 instead and resolve allocation afterwards

# Initialise geography
param = init_parameters(annealing = true, labor_mobility = false, cross_good_congestion = true, 
                        a = a, sigma = sigma, N = N, alpha = alpha, beta = beta, gamma = gamma, rho = rho, 
                        K = K, tol = 1e-5, min_iter = 15, max_iter = 45);

param, g = create_graph(param, type = "custom", x = nodes.lon, y = nodes.lat, adjacency = adj_matrix, 
                        Lj = population, Zjn = productivity, Hj = population .* (1-alpha)); # TG: I normalise this because the general utility function has a (h_j/(1-alpha))^(1-alpha) thing with it

g[:delta_i] = infra_building_matrix
g[:delta_tau] = iceberg_matrix

# Naming conventions: if IRS -> "cgc_irs"; if alpha = 0.1 -> add "_alpha01"; if with_ports = false -> add "_noport"; if frictions -> add "_bc" (border cost)
filename = "4g_50b_fixed_cgc_sigma15" # adjust if sigma != 1.5
println("File extension: $filename")

# Recommended to use coin HSL linear solvers. See README of OptimalTransportNetworks.jl and Ipopt.jl
# param[:optimizer_attr] = Dict(:hsllib => "/usr/local/lib/libhsl.dylib", :linear_solver => "ma57") # Use ma86 for optimal performance on big machine 

# Solve allocation from existing infrastructure
@time res_stat = optimal_network(param, g, I0 = infra_matrix, solve_allocation = true, verbose = true)

# Solve Optimal Network
@time res_opt = optimal_network(param, g, I0 = infra_matrix, Il = min_mask, Iu = max_mask, verbose = false)

# Check: should be 1
K / sum(res_opt[:Ijk] .* g[:delta_i])

# Plot Network
plot_graph(g, res_opt[:Ijk], height = 800) # , node_sizes = res_opt[:Cj])
plot_graph(g, res_opt[:Ijk] - infra_matrix, height = 800)

# Save
function res_to_vec(Ijk, graph)
    n = size(graph, 1)
    rv = zeros(n)
    for i in 1:n
        rv[i] = (Ijk[graph.from[i], graph.to[i]] + Ijk[graph.to[i], graph.from[i]]) / 2
    end
    return rv
end

# Saving: Nodes
res_nodes = deepcopy(nodes)
res_nodes.uj_orig = res_stat[:uj]
res_nodes.Lj_orig = res_stat[:Lj]
res_nodes.Cj_orig = res_stat[:Cj]
res_nodes.Dj_orig = res_stat[:Dj]
res_nodes.PCj_orig = res_stat[:PCj]
# res_nodes.welfare = res_opt.welfare; # Same as: sum(res_opt.Lj .* res_opt.uj)
res_nodes.uj = res_opt[:uj]
res_nodes.Lj = res_opt[:Lj]
res_nodes.Cj = res_opt[:Cj]
res_nodes.Dj = res_opt[:Dj]
res_nodes.PCj = res_opt[:PCj]
for n in 1:N
   res_nodes[!, Symbol("Lj_$(n)")] = res_opt[:Ljn][:,n]
   res_nodes[!, Symbol("Dj_$(n)")] = res_opt[:Djn][:,n]
   res_nodes[!, Symbol("Yj_$(n)")] = res_opt[:Yjn][:,n]
   res_nodes[!, Symbol("Pj_$(n)")] = res_opt[:Pjn][:,n]
end
res_nodes |> CSV.write("results/transport_network/regional/nodes_results_$filename.csv")

# Saving: Graph / Edges
res_graph = deepcopy(graph)
res_graph.Ijk_orig = res_to_vec(infra_matrix, graph)
res_graph.Ijk = res_to_vec(res_opt[:Ijk], graph)
for n in 1:N
   res_graph[!, Symbol("Qjk_$(n)")] = res_to_vec(res_opt[:Qjkn][:,:,n], graph)
end
res_graph |> CSV.write("results/transport_network/regional/edges_results_$filename.csv")
