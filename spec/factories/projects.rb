FactoryGirl.define do
  factory :project_binding do
    trait :for_project do
      transient do
        project_id 0
      end

      kind ProjectBinding.kinds[:project_id]
      value { project_id }
    end

    trait :for_namespace do
      transient do
        namespace_id 0
      end

      kind ProjectBinding.kinds[:namespace_id]
      value { namespace_id }
    end

    trait :for_all_projects do
      kind ProjectBinding.kinds[:all_projects]
    end
  end

  factory :project_info do
    initialize_with do
      gitlab_project = build(:gitlab_project)
      new(
        gitlab_project,
        build(:project_binding, :for_project, project_id: gitlab_project[:id])
      )
    end
  end

  factory :project_parameter do
    flag 0
  end

  factory :project_settings do
    public_key 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDEvUKbIyAdN5adpI9b3qgoACB5AVAAJ+EptqFxoqiYSKmqxV8LZZNfBR3w9Rm1aR9/Van/2icQy8jxcS3kHJRw/qtBM9NBga2jy6QGg33wdxCQXQmtYULmRYtLP1+o9shRxUDmOt11s6Xs3vKBNJ8wTe4vht3YOaMvJxNJs9khXZiyYIOoMPCxfbbpiyv+xWzNR6H0SeFF1o5XsPYofDakF283NmgEP6CrR9sd0ji2ngpg39/kRR+dzZdWS+3n4Ma/nZJaRLQBs90zkGiXMYClz7AZb4Nz7RvfvgXFOwPbfOdBPFwYFou4NOkTrVDl4OylNwOtZF7/QUDq6u/NelfF user@domain.tld'
    private_key '-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAxL1CmyMgHTeWnaSPW96oKAAgeQFQACfhKbahcaKomEipqsVf
C2WTXwUd8PUZtWkff1Wp/9onEMvI8XEt5ByUcP6rQTPTQYGto8ukBoN98HcQkF0J
rWFC5kWLSz9fqPbIUcVA5jrddbOl7N7ygTSfME3uL4bd2DmjLycTSbPZIV2YsmCD
qDDwsX226Ysr/sVszUeh9EnhRdaOV7D2KHw2pBdvNzZoBD+gq0fbHdI4tp4KYN/f
5EUfnc2XVkvt5+DGv52SWkS0AbPdM5BolzGApc+wGW+Dc+0b374FxTsD23znQTxc
GBaLuDTpE61Q5eDspTcDrWRe/0FA6urvzXpXxQIDAQABAoIBAHcvzSUdD3yDy6wv
IGZgqnCpOwLzp5qgjkjuCjpEd2ziQF9jeOP3omMjP3NVmUCMsfc7V2TXrWkAe/jB
PzL9mXQm5Gr40ZfSzvX3DaSgjnBaQV+j7ZPq41OLeAqbFwHOl6bqIBoaOUXwEqpA
mptp3LKv04dZZhZzPIf5XTb+TKFn+GNewCANgpAd46nEIwmCqh/MiGzhetvWnO5V
QCmrTB9PPnIwJ3JQWgsukEs55fj4S0kZUsBeMmeng2Q7Ws6F9i3fUQzvk+6SRe+3
YgrK+UjlJEBNErwkEMzBAIC/ZzxnBw5sMcCkKe+4wcKZC/oVLWfinlCc2qm+ctm9
3bP5pNUCgYEA9galMTdSJzTAsc413NpReYvGcO5cNYHXiU8ue54La1W2T9ASW5Lf
xfsQg8ggO4wGWu/BVm+y5yRcqYInrizTQcfoY/8eBptT0PBLqMYJRQQd8S12bdl3
nKDUiX84jmC+Ej82v9WEwY8UGxjWxvjQVM61SGE0xge87eYlKviLegsCgYEAzLcZ
My0p2WjTDByDtZao3SSjxR8qftWy8VKLAzDtoFpbb+14099lVSfl0U3aeU7kcG5C
SpcvByfRaIU/PVBCFZt/+utzUvetPrr4pywPKBoSyrSkRNA1shnvTL3JM64e0zgM
C1NkfVkM/Lfb13ekPWfzirLPKUx3iMlHofZyZ28CgYEA6po/oATexCAbt/GpjyZo
Fv1gh4PkTem4vGjTLHHy9bFQHh+NweD2nfXhM6j8g4vs635A4Mm20Y7tBX7lk8OO
1+VnByPZX/dyH4VkwFXHtRZN7xOpIOsEkkkTIuI77hj2ZrP840UaSPDE/WncNPRC
xPwwBgsbpdLvJ/QUcTt81S0CgYEAxHs0F5dQZFekwCoaC86HUoEZIlgQXF3U+qOj
wrNSTyaKPjopTwlJ49qATEwx1V5wCKz6uUazn2WLKotBMCL42m49/mG/dTE8uUmQ
4Dp8bZvgz2djhpxj/QXBVOGO3ChRc56GiNRITbqLqX755KrzGvDLoiKOjG/VBpdR
RlUYZscCgYEA9RVe5RT/UXkxRv1N/sYoZkLI/5WlYj1HHtlxsL9YOBHxuMVercZR
MXFqJKQ1biOfo/XHZJLdUnfGxX+zqY9G7dLFjucFrmsccAV3IUChnn998ZbGRIX3
/UFksK0nVpL/SmJWRprnUdqYq51yziO8Je3xpDV5iMMyOORbZmmfXTk=
-----END RSA PRIVATE KEY-----
'
  end
end
