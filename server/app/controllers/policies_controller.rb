class PoliciesController < ApplicationController
  # Public, static legal pages. No authentication — these have to be readable
  # before signup (the terms checkbox links here).
  def terms; end
  def privacy; end
end
