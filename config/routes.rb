RenderDashboard::Engine.routes.draw do
  get "metrics",      to: "metrics#index",  as: :metrics
  get "metrics/data", to: "metrics#data",   as: :metrics_data
end
