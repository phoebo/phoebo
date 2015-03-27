FactoryGirl.define do
  factory :task do
    build_request
    deploy_template({
      arguments: [ "phoebo --from-url \"http://phoebo.domain.tld/build_requests/f21d8b6521728e1abaf0bea0918995e0\"" ],
      containerInfo: {
        docker: {
          image: 'phoebo/phoebo:latest',
          privileged: true
        }
      }
    })
  end
end
