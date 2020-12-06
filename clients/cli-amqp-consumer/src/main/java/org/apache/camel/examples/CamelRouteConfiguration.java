/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.camel.examples;

import javax.jms.ConnectionFactory;

import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.component.amqp.AMQPComponent;
import org.apache.camel.spi.ComponentCustomizer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Component;

@Component
public class CamelRouteConfiguration extends RouteBuilder {
  
  private static final Logger log = LoggerFactory.getLogger(CamelRouteConfiguration.class);
  
  @Bean
  private ComponentCustomizer<AMQPComponent> amqpComponentCustomizer(ConnectionFactory jmsConnectionFactory) {
    return (component) -> {
      component.setConnectionFactory(jmsConnectionFactory);
    };
  }
  
  @Override
  public void configure() {
    
    from("amqp:{{amqp.destination.type:queue}}://{{amqp.destination.name}}?disableReplyTo=true")
      .to("stream:out")
    ;
  }
}
