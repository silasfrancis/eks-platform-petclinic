package org.springframework.samples.petclinic.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = {
    "spring.profiles.active=native",
    "spring.cloud.config.server.native.search-locations=classpath:/config"
})
class PetclinicConfigServerApplicationTests {

    @Test
    void contextLoads() {
    }

}