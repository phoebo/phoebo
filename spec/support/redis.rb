RSpec.shared_context 'redis' do
  # Define Redis mock for global with_redis call
  let(:redis) do
    redis = instance_double(Redis)
    allow_any_instance_of(Object).to receive(:with_redis).and_yield(redis)
    allow(redis).to receive(:multi).and_yield
    redis
  end

  # Ensure Redis mock is performed even if we forget to explicitly define it's expectations
  before do
    redis
  end
end