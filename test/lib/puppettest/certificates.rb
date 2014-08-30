# Certificate-related helper methods.

require 'puppettest'

module PuppetTest::Certificates
    include PuppetTest

    def mkPassFile()
        keyfile = File.join(@dir, "tmpkeyfile")
        @@tmpfiles << keyfile
        unless FileTest.exists?(@dir)
            system("mkdir -p %s" % @dir)
        end
        File.open(keyfile, "w", 0600) { |f|
            f.print "as;dklj23rlkjzdflij23wr"
        }

        return keyfile
    end

    def mkCA
        ca = nil
        assert_nothing_raised {
            ca = Puppet::SSLCertificates::CA.new()
        }

        return ca
    end

    def mkStore(ca)
        store = OpenSSL::X509::Store.new
        store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
        store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK
        store.add_cert(ca.cert)
        store.add_crl(ca.crl)
        store
    end

    def mkcert(hostname)
        cert = nil
        assert_nothing_raised {
            cert = Puppet::SSLCertificates::Certificate.new(:name => hostname)
            cert.mkcsr
        }

        return cert
    end

    def mksignedcert(ca = nil, hostname = nil)
        ca ||= mkCA()
        hostname ||= "ttltest.example.com"

        cert = nil
        assert_nothing_raised {
            cert, cacert = ca.sign(mkcert(hostname).mkcsr)
        }
        return cert
    end
end

