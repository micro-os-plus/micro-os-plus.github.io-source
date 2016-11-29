---
layout: page
lang: pt
permalink: /pt/user-manual/threads/
title: Threads
author: Liviu Ionescu
translator: Carlos Delfino

date: 2016-07-05 11:27:00 +0300
last_modified_at: 2016-11-10 00:16:00 +0300

---
{% comment %} 

Start translate at: 2016-08-19 00:10:00 +300 Todo:

Base Commit:
- aac11b8d05198ec0a390c2c046e9578e92726ad0
- f16bc9f0b4f524ee5ccd7f2929ebc6ceb84a644a
{% endcomment %}
 
## Visão Geral

Uma das primeiras decisões durante o projeto de uma aplicação _real-time_ é como
particionar as funcionalidades demandada em cada tarefa em separado, tal que cada 
tarefa é tão simples quanto possível e tem o mínimo de interação com outras 
tarefas.

µOS++ torna fácil para um programador adotar este paradigma. Cada **tarefa** é 
executada por uma **thread separada** e pode conversar com as outras _threads_ 
e com ISRs via diversas primitivas de comunicação/sincronização.

Uma _thread_ é um simples programa que pensa ter a CPU toda para ele. Em uma 
simples CPU, somente uma _thread_ pode executar a cada certo tempo.

µOS++ suporta multi tarefa e permite a aplicação ter 
**qualquer quantidade de _threads_**. O número máximo de _threads_  é atualmente 
somente o limite de quantidade de memória disponível no processador (ambos espaço 
de código e dados).

Multitarefa é o processo de escalonamento e troca na CPU entre diversas _threads_. 
A CPU chaveia sua atenção A CPU troca sua atenção entre diversas _threads_. 
Multitarefa prove a ilusão de ter múltiplas CPUs e, atualmente maximiza o uso da 
CPU.

Multitarefa também ajuda a criação de aplicação modular. Sem multitarefa, a 
aplicação é normalmente um superloop, com giros através de um ou varias máquinas 
de estado finitos. Com multitarefa, o programador da aplicação tem que gerenciar 
tarefas muito simples e lineares. Programação tipicamente fáceis de projetar e 
manter quando é usado multitarefa.

_Threads_ separadas são usadas para tais como monitoramento de entradas, 
atualização de saída, executar cálculos, controlar laços (loops), atualizar um 
ou mais _displays_, ler botões e teclados, comunicar com outros sistemas, e mais. 
Uma aplicação pode conter um punhado de _threads_ enquanto outra aplicação pode 
requerer centenas. O número de _threads_ não estabelece o quanto bom ou efetivo 
um projeto pode ser, ele realmente depende do que a aplicação (ou produto) precisa 
fazer. A quantidade de trabalho que uma _thread_ executa também depende da 
aplicação. Uma _thread_ pode ter alguns microssegundos que valem a pena o 
trabalho executado enquanto outra _thread_ pode requerer dezenas de milissegundos.

Tarefas são implementadas como funções regulares em C, passadas para a chamadas 
de criação das _threads_ como parâmetros obrigatórios.

## Funções _Thread_

Há dois tipos de threads: *run-to-completion* (execute até terminar) e 
**infinite loop** (laço infinito). Em muitos sistemas embarcados, _threads_ 
tipicamente são executadas como laços infinitos.

Como especificado pelo POSIX, **_threads_ podem terminar**, e como tal,  µOS++ 
implementa adequamento ambas as _threads_ _run-to-completion_ e _infinit loop_.

Além de ter protótipo especifico, funções de _threads_ são funções tipicas do C; 
Como tal elas se beneficiam de todos os recursos da função C, incluindo ter 
variáveis locais em sua pilha, chamando quantas funções ela precisar, etc.

``` c++
// Thread function.
void*
th_func(void* args)
{
  // Define local variables, as needed.

  // Do something useful.
  // Consider args when multiple threads use the same function.

  // When nothing to do, return.
  return nullptr;
}
```

### Funções reentrantes de _Thread_

Quando uma _thread_ µOS++ inicia sua execução, é passado um argumento opcional 
do tipo `void*`, **args**. Este ponteiro é um veiculo universal que pode ser 
usado para passar para a _thread_ o endereço de uma variável, o endereço de uma 
estrutura, ou o endereço de uma função, se necessário. Com este ponteiro, é 
possível criar muitas _threads_ idênticas, todas usando o mesmo corpo de _thread_ 
reentrante, mas será executado com dados de tempo de execução diferentes.

Uma função _reentrante_ é uma função que não faz uso de variáveis estáticas ou 
mesmo globais mesmo que elas estejam protegidas.

Um exemplo de uma função não reentrante é a famosa `strtok()` fornecida pela 
maioria das bibliotecas C padrão. Esta função é usada para buscar em strings 
por _tokens_. A primeira vez que esta função é chamada, a _string_ a ser 
analisada e os _tokens_ devem ser informados. Assim que a função encontra o 
primeiro _token_, ela retorna. A função _lembra_ quando foi a última vez que ela 
foi chamada novamente, e pode extrair novos _tokens_, o que é claramente não 
reentrante.  Mas tais funções são identificadas e agora versões reentrantes 
estão disponíveis nas bibliotecas padrão (no caso desta `strtok_r()`).

Como um exemplo de funções reentrantes de _thread_, uma aplicação pode ter quatro 
portas seriais assíncronas que são cada uma gerenciada pela sua própria _thread_. 
Porem, a função da _thread_ são atualmente idênticas, Ao invés de copiar o código 
quatro vezes, crie o código para uma _thread_ genérica que recebe um ponteiro 
para a estrutura de dados, que contem os parâmetros da porta serial (baud rate, 
endereço da porta I/O, numero do vetor de interrupção, etc.) como argumento. em 
outras palavras, instanciar o mesmo código de _thread_ quatro vez e passar dados 
diferentes para cada porta serial que cada instância pode gerenciar.

### _Threads_ Run-to-completion (execute até terminar)

Uma _thread_ µOS++ _run-to-completion_é implementada como uma função que termina 
e opcionalmente retorna um ponteiro. alternativamente ela pode explicitamente 
chamar o  `this_thread::exit(void*)`, com resultados idênticos.

Uma _thread_ _run-to-completion_ inicia, executa sua função, e termina, depois 
esta _thread_ pode ser reusada quantas vezes for necessário. Porém, há uma certa 
sobrecarga envolvendo a criação e destruição de _threads_, e, se a _thread_ não 
é configurada para usar uma pilha (_stack_) estático, a área de _stack_ deve ser 
alocada e desalocada cada vez, que não somente aumenta o _overhead_, mas também 
pode contribuir pra a fragmentação.

``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>

using namespace os;
using namespace os::rtos;

// Thread function.
void*
th_func(void* args)
{
  // Do something useful.

  return nullptr;
}

int
os_main (int argc, char* argv[])
{
  // ...

  // Create the thread. Stack is dynamically allocated.
  thread th { "th", th_func, nullptr };

  // Wait for the thread to terminate.
  th.join();

  // ...

  // The local thread is destroyed automatically before exiting this block.
  return 0;
}
```

Um exemplo similar, mas escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>

// Thread function.
void*
th_func(void* args)
{
  // Do something useful.

  return NULL;
}

int
os_main (int argc, char* argv[])
{
  // ...

  // Local storage for the thread object instance.
  os_thread_t th;

  // Initialise the thread object and allocate the thread stack.
  os_thread_create(&th, "th", th_func, NULL, NULL);

  // ...

  // Wait for the thread to terminate.
  os_thread_join(&th, NULL);

  // ...

  // For completeness, destroy the thread.
  os_thread_destroy(&th);

  return 0;
}
```

### _Threads_ de loop infinito

O uso de _threads_ de loop infinito são mais comuns em sistemas embarcados, 
porque trabalho repetitivo é necessário neste tipo de sistema (leitura de 
entradas, atualização de _displays_, execução de operações de controles, etc).

Observe que elas podem usar um `while (true)` ou um `for (;;)` para implementar 
o loop infinito, já que ambos tem o mesmo comportamento.

O _loop_ infinito deve chamar um serviço do µOS++ que faz a _thread_ retornar 
o controle para o escalonador, por exemplo um serviço para aguadar por um evento 
ocorrer, ou adormecer por um certo tempo. É importante que cada _thread_ passe 
o controle de volta ao escalonador, caso contrário a _thread_ será  
verdadeiramente um loop ocupado e simplesmente monopolizando a CPU pelo tempo 
que for permitida sua execução. Este conceito de 
**suspender a _thread_ em enquanto espera** é a chave para o uso eficiente da 
CPU em qualquer RTOS.

``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>

using namespace os;
using namespace os::rtos;

typedef struct msg_s
{
  uint8_t id;
  uint8_t payload[7];
} msg_t;

// Define a queue of 7 messages.
// The queue itself will be dynamically allocated.
message_queue_typed<msg_t> mq { 7 };

// Thread function.
void*
th_func(void* args)
{
  while (true)
  {
    msg_t msg;
    mq.receive(&msg);

    trace::printf("id: %d\n", msg.id);
  }

  return nullptr;
}
```

Um exemplo similar, mas escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>

typedef struct msg_s
{
  uint8_t id;
  uint8_t payload[7];
} msg_t;

// Global static storage for the queue object instance.
// The queue itself will be dynamically allocated.
os_mqueue_t mq;

// Thread function.
void*
th_func(void* args)
{
  while (true)
  {
    msg_t msg;
    os_mqueue_receive(&mq, &msg, sizeof(msg), NULL);

    trace_printf("id: %d\n", msg.id);
  }

  return NULL;
}
```

O serviço do µOS++, usado neste exemplo para passar o controle de volta ao 
escalonador é a função que recebe da fila, a _thread_ não terá nada para fazer 
até a mensagem ser recebida. Uma vez a mensagem é enviada para a fila, a 
_thread_ será retomada e a mensagem consumida.

Outra situação comum a _thread_ pode estar aguardando o tempo passar. Por 
exemplo, um projeto pode precisar varrer um teclado a cada 100 _ticks_. Neste 
caso, simplesmente suspenda a _thread_ por 100 _ticks_ (`sysclock.sleep_for(100)`) 
então verifique se a tecla foi pressionada no teclado e, possivelmente execute 
alguma ação baseada no que foi pressionado.

É importante observar que quando a _thread_ é suspendida e aguarda por um evento, 
ela não deve consumir algum tempo da CPU.

## Prioridade das _Thread_ 

A regra usada pelo escalonador do µOS++ para selecionar a próxima _thread_ 
são simples:

 - selecione a _thread_ com a maior prioridade
 - se há múltiplas _threads_ com esta prioridade, selecione uma que está 
   aguardando a mais tempo.

Em resumo, isso pode ser reescrito assim:

> A _thread_ que espera a mais tempo com a maior prioridade

Prioridades das _threads_ são valores sem sinal, com valores maiores 
representando maior prioridade.

µOS++ não impõem restrições de como prioridades podem ser designadas para 
_threads_. A escolha pode ser qualquer uma desde que uma única prioridade para 
cada _thread_ (como exigido por alguma escalonamento especialmente estratégico), 
para designar a mesma prioridade para todas as _threads_. por padrão, todas as 
_threads_ são criadas com a prioridade `normal`.

## Criando _threads_

Criar as _threads_ sejam provavelmente a parte mais complexa de alguma API RTOS, 
e é infelizmente é o primeiro problema que é encontrado quando litando com um 
novo RTOS, mas _threads_ devem ser dominadas assim que possível já que são um 
componente fundamental de sistemas multitarefa.

Por razões de conveniência, µOS++ tem tem um conjunto rico de funções para criar 
_threads_. _Threads_ podem ser usadas em pilhas alocadas estaticamente ou 
dinamicamente, _threads_ podem ser criadas como objetos locais na pilha de 
funções, ou podem ser objetos globais, _threads_ podem ser criadas com 
características padrões ou com atributos personalizados, e assim por diante.

Para _threads_ de loop infinito, a forma fácil de criar a _thread_ é através 
de um objeto global.

Em C++, as _threads_ globais são criadas e inicializadas pelo mecanismo de 
construtor estático global, portanto elas são já _lincadas_ a lista READY 
quando `main()` é executado.


``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>
#include <my-allocator.h>

using namespace os;
using namespace os::rtos;

// Thread function.
void*
th_func(void* args)
{
  while (true)
    {
      // Do something useful.
    }

  return nullptr;
}

// Create a thread; the stack is allocated with the default RTOS allocator.
thread th1 { "th1", th_func, nullptr };

// Define a custom thread type, parametrised with the user allocator.
using my_allocated_thread = thread_allocated<my_allocator>;

// Create a thread; the stack is allocated with the user allocator.
my_allocated_thread th2 { "th2", th_func, nullptr };

constexpr std::size_t my_stack_size_bytes = 3000;

// Create a thread; the stack is statically allocated.
thread_static<my_stack_size_bytes> th3 { "th3", th_func, nullptr };

int
os_main (int argc, char* argv[])
{
  // ...

  // Not much to do, the threads were created by the static
  // constructors, before entering main(), and are already running.

  // ...

  // Wait for the threads to terminate.
  th1.join();
  th2.join();
  th3.join();

  return 0;
}

// All threads are automatically destroyed if os_main() returns.

```

Um exemplo similar, escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>
#include <my-allocator.h>

// Thread function.
void*
th_func(void* args)
{
  while (true)
    {
      // Do something useful.
    }

  return NULL;
}

// Global static storage for the thread object instance.
os_thread_t th1;

// Global static storage for the thread object instance.
os_thread_t th2;

#define MY_STACK_SIZE_BYTES 3000
// Static storage for the thread stack.
os_thread_stack_allocation_element_t
th3_stack[MY_STACK_SIZE_BYTES/sizeof(os_thread_stack_allocation_element_t)];

// Global static storage for the thread object instance.
os_thread_t th3;

int
os_main (int argc, char* argv[])
{
  // ...

  // Create a thread; the stack is allocated with the default RTOS allocator.
  os_thread_create(&th1, "th1", th_func, NULL, NULL);

  // The default stack size.
  size_t my_size = os_thread_stack_get_default_size();

  os_thread_attr_t attr2;
  os_thread_attr_init(&attr2);
  attr2.th_stack_address = my_allocator_allocate(my_size);
  attr2.th_stack_size_bytes = my_size;

  // Create a thread; the stack is allocated with the user allocator.
  os_thread_create(&th2, "th2", th_func, NULL, &attr2);

  os_thread_attr_t attr3;
  os_thread_attr_init(&attr3);
  attr3.th_stack_address = th3_stack;
  attr3.th_stack_size_bytes = sizeof(th3_stack);

  // Create a thread; the stack is allocated with the user allocator.
  os_thread_create(&th3, "th3", th_func, NULL, &attr3);

  // ...

  // Wait for the threads to terminate.
  os_thread_join(&th1, NULL);
  os_thread_join(&th2, NULL);
  os_thread_join(&th3, NULL);

  // For completeness, destroy the threads.
  os_thread_destroy(&th1);
  os_thread_destroy(&th2);
  os_thread_destroy(&th3);

  // Free the allocated stack.
  my_allocator_deallocate(attr2.th_stack_address, attr2.th_stack_size_bytes);

  return 0;
}
```

Em C++, se há necessidade de controlar o momento quando instancia de um objeto 
global é criado, é possível separadamente alocar o armazenado como as variáveis 
globais, então usar no lugar o operador `new` para inicializa-la.


``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>
#include <my-allocator.h>

using namespace os;
using namespace os::rtos;

// Thread function.
void*
th_func(void* args)
{
  while (true)
    {
      // Do something useful.
    }

  return nullptr;
}

// Global static storage for the thread object instance.
// This storage is set to 0 as any uninitialised variable.
std::aligned_storage<sizeof(thread), alignof(thread)>::type th1;

int
os_main (int argc, char* argv[])
{
  // ...

  // Use placement new, to explicitly call the constructor
  // and initialise the thread.
  new (&th1) thread { "th1", th_func, nullptr };

  // Local static storage for the thread object instance.
  std::aligned_storage<sizeof(thread), alignof(thread)>::type th2;

  // Use placement new, to explicitly call the constructor
  // and initialise the thread.
  new (&th2) thread { "th2", th_func, nullptr };

  // ...

  // Wait for the thread to terminate.
  th1.join();

  // For completeness, call the threads destructors, which for placement new
  // is no longer called automatically.
  th1.~thread();
  th2.~thread();

  return 0;
}
```

As instâncias de objetos de _threads_ podem também ser criados no _stack_ 
local, por exemplo no _stack_ da _thread_ principal. Certifique-se que o 
_stack_ é grande o suficiente para armazenar todas as definições de objetos 
locais.


``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>
#include <my-allocator.h>

using namespace os;
using namespace os::rtos;

// Thread function.
void*
th_func(void* args)
{
  while (true)
    {
      // Do something useful.
    }

  return nullptr;
}

constexpr std::size_t my_stack_size_bytes = 3000;

thread::stack::allocation_element_t
th3_stack[my_stack_size_bytes/sizeof(thread::stack::allocation_element_t)];

int
os_main (int argc, char* argv[])
{
  // ...

  // Create a thread; the stack is allocated with the default RTOS allocator.
  thread th1 { "th1", th_func, nullptr };

  // Define a custom thread type, parametrised with the user allocator.
  using my_allocated_thread = thread_allocated<my_allocator>;

  // Create a thread; the stack is allocated with the user allocator.
  my_allocated_thread th2 { "th2", th_func, nullptr };

  thread::attributtes attr;
  attr.th_stack_address = th3_stack;
  attr.th_stack_size_bytes = sizeof(th3_stack);

  // Create a thread; the stack is statically allocated.
  thread th3 { "th3", th_func, nullptr, attr };

  // Beware of local static instances, since they'll use atexit()
  // to register the destructor; avoid and prefer placement new, as before.
  // static thread th4 { "th4", th_func, nullptr };

  // ...

  // Wait for the threads to terminate.
  th1.join();
  th2.join();
  th3.join();

  // The local threads are destroyed automatically before exiting this block.
  return 0;
}
```

Um exemplo similar escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>
#include <my-allocator.h>

// Thread function.
void*
th_func(void* args)
{
  while (true)
    {
      // Do something useful.
    }

  return NULL;
}

#define MY_STACK_SIZE_BYTES 3000
// Static storage for the thread stack.
os_thread_stack_allocation_element_t
th3_stack[MY_STACK_SIZE_BYTES/sizeof(os_thread_stack_allocation_element_t)];

int
os_main (int argc, char* argv[])
{
  // ...

  // Local storage for the thread object instance.
  os_thread_t th1;

  // Create a thread; the stack is allocated with the default RTOS allocator.
  os_thread_create(&th1, "th1", th_func, NULL, NULL);

  // The default stack size.
  size_t my_size = os_thread_stack_get_default_size();

  os_thread_attr_t attr2;
  os_thread_attr_init(&attr2);
  attr2.th_stack_address = my_allocator_allocate(my_size);
  attr2.th_stack_size_bytes = my_size;

  // Local storage for the thread object instance.
  os_thread_t th2;

  // Create a thread; the stack is allocated with the user allocator.
  os_thread_create(&th2, "th2", th_func, NULL, &attr2);

  os_thread_attr_t attr3;
  os_thread_attr_init(&attr3);
  attr3.th_stack_address = th3_stack;
  attr3.th_stack_size_bytes = sizeof(th3_stack);

  // Local storage for the thread object instance.
  os_thread_t th3;

  // Create a thread; the stack is statically allocated.
  os_thread_create(&th3, "th3", th_func, NULL, &attr3);

  // ...

  // Wait for the threads to terminate.
  os_thread_join(&th1, NULL);
  os_thread_join(&th2, NULL);
  os_thread_join(&th3, NULL);

  // Free the allocated stack.
  my_allocator_deallocate(attr2.th_stack_address, attr2.th_stack_size_bytes);

  // For completeness, destroy the threads.
  os_thread_destroy(&th1);
  os_thread_destroy(&th2);
  os_thread_destroy(&th3);

  return 0;
}
```
O Programador da aplicação pode criar um numero ilimitado de _threads_ 
(limitado apenas pela disponibilidade de memoria RAM).

### _Threads_ ISO/IEC C++

A liberação em 2011 do padrão ISO/IEC C++ 14882 finalmente introduziu uma 
definição de padrão para objetos de _threads_ em C++.

Este definição padrão foi definida com _threads_ POSIX em mente, e o padrão 
de _threads_ C++ não tem intenção de reimplementar as _threads_ POSIX no C++, 
mas se parecer como _wrapper_ C++ no topo de _threads POSIX em C existentes.

Com as _threads_ µOS++/CMSIS++ sendo uma implementação em C++ das _threads_ 
POSIX, o _wrapper_ ISO/IEC se aproxima 1:1 as _threads_ µOS++.

Pra evitar conflitos com a biblioteca padrão  quando executando testes em uma 
plataformas sintéticas que já implementem o padrão C++ para _threads_, as 
definições são parte do _namespace_ `os::estd::` ("embedded" std), ao invés 
do _namespace_ `std::`.

Quando usando o _namespace_ `os::estd::` é recomendado evitar definições 
`using namespace` abaixo do _namespace_ `os`; ao invés, use o _namespace_ 
`rtos` e `estd` explicitamente.


``` c++
/// @file app-main.cpp
#include <cmsis-plus/iso/thread>

using namespace os;

// Thread function.
void*
th_func(int n, char* s, void* p)
{
  // Note the 3 different parameters.

  // Do something useful.

  return nullptr;
}

int
os_main (int argc, char* argv[])
{
  // ...

  // Create a standard thread.
  // The underlying implementation thread object and
  // stack are dynamically allocated.
  estd::thread th1 { th_func, 7, "str", nullptr };

  // ...

  // Wait for the thread to terminate.
  th1.join();

  // The local thread is destroyed automatically before exiting this block.
  return 0;
}
```

A expectativa de implementação padrão de aloca  dinamicamente, de instâncias 
adjacentes do objeto `rtos::thread`, que por sua vez aloca o _stack_; Não é 
possível configurar _stacks_ estáticos com _threads_ ISO C++, nem definir o 
nome da _thread_.

Deve ser observado que as _threads_ C++ podem ter algum número de argumentos. 
A implementação interna usa _tuplas_ e `std::bin`, que também implica em 
alocação dinâmica de memória.

Para maiores detalhes, por favor leia a especificação 
_Linguagens de Programação C++ – ISO/IEC 14882:2011(E)_.

## Alterando as prioridades das _thread_

Por padrão, _threads_ são criadas com `thread::priority::normal` que é valor 
médio para prioridade, mas ele pode ser alterado em qualquer momento durante 
o tempo de vida da _thread_

``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>

using namespace os;
using namespace os::rtos;

// Thread function.
void*
th_func(void* args)
{
  this_thread::thread().priority(thread::priority::high);

  // Do something useful.

  return nullptr;
}
```

Um exemplo similar, mas escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>

// Thread function.
void*
th_func(void* args)
{
  os_thread_set_priority(os_this_thread(), os_thread_priority_high);

  // Do something useful.

  return NULL;
}
```

Se, por alguma razão, a prioridade inicial da _thread_ deve ser diferente, 
ela pode ser definida para um dos valores permitidos durante a sua criação, 
usando o atributo `th_priority` da _thread_.

``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>
#include <my-allocator.h>

using namespace os;
using namespace os::rtos;

// Thread function.
void*
th_func(void* args)
{
  while (true)
    {
      // Do something useful.
    }

  return nullptr;
}

int
os_main (int argc, char* argv[])
{
  // ...

  thread::attributtes attr;
  attr.th_priority = thread::priority::high;

  // Create a thread; the stack is allocated with the default RTOS allocator.
  // The initial priority is configured via the attributes as HIGH.
  thread th1 { "th1", th_func, nullptr, attr };

  // ...

  // Wait for the thread to terminate.
  th1.join();

  // The local thread is destroyed automatically before exiting this block.
  return 0;
}
```

Um exemplo similar, mas escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>
#include <my-allocator.h>

// Thread function.
void*
th_func(void* args)
{
  while (true)
    {
      // Do something useful.
    }

  return NULL;
}

int
os_main (int argc, char* argv[])
{
  // ...

  os_thread_attr_t attr;
  os_thread_attr_init(&attr);
  attr.th_priority = os_thread_priority_high;

  // Local storage for the thread object instance.
  os_thread_t th1;

  // Create a thread; the stack is allocated with the default RTOS allocator.
  // The initial priority is configured via the attributes as HIGH.
  os_thread_create(&th1, "th1", th_func, NULL, &attr);

  // ...

  // Wait for the thread to terminate.
  os_thread_join(&th1, NULL);

  // For completeness, destroy the thread.
  os_thread_destroy(&th1);

  return 0;
}
```

## Outras funções de _thread_

A API de _thread_ do  µOS++ basicamente implementa _threads_ POSIX, com várias 
extensões.


### Obter o nome da _thread_

O nome da _thread_ é uma _string_ opcional definido durante a criação da 
instância do objeto _thread_. Ele é geralmente usado para identificar a _thread_ 
durante seções de depuração.

A API no C++:

``` c++
thread th { "th", th_func, nullptr };

const char* name = th.name();
```

A API no C é:

``` c
os_thread_t th;
os_thread_create(&th, "th", th_func, NULL, NULL };

const char* name = os_thread_get_name(&th);
```

### definindo/obtendo a prioridade da _thread_

A prioridade da _thread_ pode ser acessada e modificada pela própria _thread_, 
ou por outras _threads_

A API no C++:

``` c++
thread th { "th", th_func, nullptr };

thread::priority_t prio = th.priority();
th.priority(thread::priority::high);
```
A API no C é:

``` c
os_thread_t th;
os_thread_create(&th, "th", th_func, NULL, NULL };

os_thread_priority_t prio = os_thread_get_priority(&th);
os_thread_set_priority(&th, os_thread_priority_high);
```

### Obtendo o _stack_ da _thread_

O `thread::stack` é um objeto separado, gerenciando o _stack_ da _thread_; o 
armazenamento do _stack_ por si próprio não é armazenado neste objeto, mas 
somente um ponteiro para ele está disponível.

A API no C++ é:

``` c++
thread th { "th", th_func, nullptr };

thread::stack& stack = th.stack();
std::size_t sz = stack.size();
std::size_t available = stack.available();
stack::element_t* bottom = stack.bottom();
stack::element_t* top = stack.top();
bool bm = stack.check_bottom_magic();
bool tm = stack.check_top_magic();
```

A API no C é:

``` c
os_thread_t th;
os_thread_create(&th, "th", th_func, NULL, NULL };

os_thread_stack_t* stack = os_thread_get_stack(&th);
size_t sz = os_thread_stack_get_size(stack);
size_t available = os_thread_stack_get_available(stack);
os_thread_stack_element_t* bottom = os_thread_stack_get_bottom(stack);
os_thread_stack_element_t* top = os_thread_stack_get_top(stack);
bool bm = os_thread_stack_check_bottom_magic(stack);
bool tm = os_thread_stack_check_top_magic(stack);
```

### Obtendo o armazenamento de nível de usuário da _thread_

O armazenamento de nível de usuário da _thread_ é uma estrutura definida pelo 
usuário adicionada a cada armazenamento da _thread_.

A API em C++ é:

``` c++
thread th { "th", th_func, nullptr };

os_thread_user_storage_t* p = = th.user_storage();
```

Um exemplo similar, mas escrito em C:

``` c
os_thread_t th;
os_thread_create(&th, "th", th_func, NULL, NULL };

os_thread_user_storage_t* p = os_thread_get_user_storage(&th);
```

O conteúdo de `os_thread_user_storage_t` deve ser definido em  `os-app-config.h`, 
juntamente com `OS_INCLUDE_RTOS_CUSTOM_THREAD_USER_STORAGE`, que habilita os 
recursos de armazenamento a nível de usuário.

### Interrupção da _Thread_

Com o proposito de tratar processamento de erros, é muito útil para monitoramento 
da _thread_ ser possível interromper outra _thread_ bloqueada esperando uma 
função.

para este proposito, cada _thread_ tem um _flag_ *interrupted* (interrompida), 
que pode ser ativado/redefinido e verificado.

Quando este _flag_ é definida, a _thread_ é retomada e a função bloqueada, se 
escrita cuidadosamente, deve verificar este _flag_ e retornar `EINTR`.

Depois de detectar a condição `EINTR`, a _thread_ interrompida deve limpar o 
_flag_, com  `thread::interrupt(false)` (em C `os_thread_set_interrupt(false)`).

``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>

using namespace os;
using namespace os::rtos;

// Thread function.
void*
th_func(void* args)
{
  // Block on a long sleep.
  result_t res = sysclock.sleep_for(99999999);
  if (res == EINTR)
    {
      this_thread::thread().interrupt(false);
    }

  return nullptr;
}

int
os_main (int argc, char* argv[])
{
  // ...

  // Create a thread; the stack is allocated with the default RTOS allocator.
  // The initial priority is configured via the attributes as HIGH.
  thread th1 { "th1", th_func, nullptr, nullptr };

  // Request for thread interruption.
  th1.interrupt();

  // ...

  // Wait for the thread to terminate.
  th1.join();

  // The local thread is destroyed automatically before exiting this block.
  return 0;
}
```

Um exemplo similar, mas escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>

// Thread function.
void*
th_func(void* args)
{
  // Block on a long sleep.
  os_result_t res = os_sysclock_sleep_for(99999999);
  if (res == EINTR)
    {
      os_thread_interrupt(os_this_thread(), false);
    }

  return NULL;
}

int
os_main (int argc, char* argv[])
{
  // ...

  // Local storage for the thread object instance.
  os_thread_t th1;

  // Create a thread; the stack is allocated with the default RTOS allocator.
  // The initial priority is configured via the attributes as HIGH.
  os_thread_create(&th1, "th1", th_func, NULL, &attr);

  // Request for thread interruption.
  os_thread_interrupt(&th1, true);

  // ...

  // Wait for the thread to terminate.
  os_thread_join(&th1, NULL);

  // For completeness, destroy the thread.
  os_thread_destroy(&th1);

  return 0;
}
```

## Destruindo _threads_

Se para uma _thread_ de loop infinito isso não é um problema, desde que ela 
nunca precise ser destruída, para _threads_ _run-to-completion_ é importante a 
propriedade de ser finalizada, para assegurar que todos os recursos sejam 
liberados.

Há varias formas formas de se finalizar uma _thread_:

 - retornar da função definida para a _thread_, que  automaticamente invoca 
   `this_thread::exit()`
 - invocando manualmente `this_thread::exit()`
 - Uma _thread_ pode matar outra _thread_ usando `thread::kill()`
 - para _threads_ definidas no escopo local, se o bloco finaliza, o destrutor 
   da _thread_ é automaticamente invocado (em C, deve ser manualmente invocado 
   `os_thread_destroy()`).

Todos estes métodos são funcionalmente equivalentes, todas as _thread_ são 
destruída e se o _stack_ da _thread_  foi dinamicamente alocado, este 
armazenamento é automaticamente desalocado.

Há uma certa diferença quando a _thread_ decide terminar a si mesma (chamando 
`exit()` ou retornando de uma função da _thread_, o que é exatamente a mesma 
coisa): A finalização da _thread_ pode proceder somente um ponto, mas não pode 
completar a desalocação do _stack_ quando enquanto continua usando-o. Para 
resolver esto, em µOS++ a _thread_ adiciona a si mesma para a lista que será 
processada depois pela _idle_ _thread_ e pela próxima vez que _idle_ é 
escalonada, o _stack_ será desalocado e a destruição da _thread_ será 
finalizada.

Em um sistema bem comportado isto não é um problema, porque a _thread_ _idle_ 
é agendada com bastante frequência, mas em um sistema sobrecarregado pode 
levar um certo tempo.

Se a _thread_ é necessária para reuso imediato, é recomendado que as _threads_ 
pais invoquem `thread::kill()`, o que irá destruir a _thread_ na hora, sem ter 
que esperar pela _idle_ atuar como um matador.


## A _thread_ corrente

Algumas funções de _thread_ (como `suspend()`) somente podem ser executadas na 
_thread_ corrente, em outras palavras uma _thread_ não pode suspender outra, 
somente a própria _thread_ pode faze-lo.

Para acessar funções especiais, em C++, um _namespace_ dedicado `this_thread` 
é usado (em C uma família de funções prefixadas com òs_this_thread_ é definida).

Para funções mais especificas, uma referência para a corrente _thread_ pode 
ser obtida com `this_thread::thread()`(em C com `os_this_thread()`);

``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>

using namespace os;
using namespace os::rtos;

// A thread function.
void*
th_func(void* args)
{
  trace::printf("Thread name: %s\n", this_thread::thread().name());

  // Do something.

  return nullptr;
}
```

Um exemplo similar, escrito em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>

// A thread function.
void*
th_func(void* args)
{
  trace_printf("Thread name: %s\n", os_thread_name(os_this_thread());

  // Do something.

  return NULL;
}
```

## Estados da _Thread_

Uma _thread_ pode estar em um de vários estados em um dado momento. O principal 
distinção é baseado na presença de uma _thread_ na lista _READY_; uma _thread_ 
na lista _READ_ é dizer que está no estado **pronto** (**read**).

<div style="text-align:center">
<img src="{{ site.baseurl }}/assets/images/2016/thread-states.png" />
</div>

A área de memória associada com a uma _thread_ que ainda não foi criada pode 
ter algum conteúdo, e a _thread_ é considerada estar no estado **indefinido** 
(**undefined**).

Quando a _thread_ é criada, ela é colocada no estado **pronto** (**ready**).

### O estado pronto (ready)

Quando as _threads_ estão prontas para executar, elas são inseridas em uma lista 
_READY_  e ao mesmo tempo são colocadas no estado **pronto** (**ready**).

No próximo ponto de escalonamento, a _thread_ mais antiga de alta prioridade 
_pronta_ pega a CPU e é colocada no estado **em execução** (**running**).

### O estado em execução (running)

Somente uma _thread_ pode estar **em execução** (**running**) por vez. se uma 
_thread_ com alta prioridade se torna **pronta** (**ready**), a _thread_ em 
execução no momento é preempitada e movida de volta para o estado **ready**; 
a _thread_ de maior prioridade se torna a _thread_ **em execução**.

A _thread_ **em execução** pode encontrar a se mesmo sem nada mais para fazer 
no momento; neste caso é colocada no estado **suspenso** (**suspended**) e a 
próxima _thread_ de alta prioridade no estado **ready** é ativada.

### O estado suspenso (suspended)

Quando _threads_ são removidas da lista READY, elas são colocadas no estado 
**suspenso** (**suspended**).

Internamente, µOS++ tem uma simples função para suspender uma _thread_  
(`this_thread::suspend()`) e ela não diferencia entre estados de suspensão, 
ela não faz distinção se a _thread_ está suspensa por aguardar por um _mutex_ 
se tornar destravado, pelo tempo do software expirar ou por um prazo interromper 
uma espera.

Na API pública, todas as funções de espera, com ou sem prazos, são implementadas 
sobre a função `this_thread::suspend()` (atualmente na função interna 
`port::scheduler::reschedule()` também usada para implementar 
`this_thread::suspend()`).

O escalonador por si mesmo não mantem controle das _threads_ suspensas, ele é 
o responsável pela sincronização de objetos que suspenderam as _threads_ para 
liga-las a um objeto especifico (mutex, semáforos, etc) a lista de espera, e 
possivelmente a lista de espera.

µOS++ tem uma função simples para retomar a _thread_ (`thread::resume()`) e 
não faz diferença porque a _thread_ foi suspensa, ela é retomada e colocada no 
estado **pronto** (**ready**) de qualquer forma.

### O estado finalizado (terminated)

Quando uma _thread_ é finalizada, ela é primeira colocada no estado **finalizado** 
(**terminated**), e depois os recursos associados com ela são liberados, então 
é colocada no estado **destruída** (**destroyed**).

## A pilha (stack) da Thread

A pilha da _thread_  tem a mesma função que em um sistema de _thread_ simples: 
armazenar o endereço de retorno das funções encadeadas, parametros e variáveis 
locais, e armazenamento temporário de resultados intermediários e valores dos 
registradores.

### O quanto de pilha (stack) é exigido?

Cada _thread_ tem sua própria pilha (_stack_), que tem um valor fixo determinado 
durante a criação da _thread_, e cada _thread_ tem seu próprio padrão de uso da 
pilha. É muito dificil calcular o tamanho exato da pilha necessário para uma 
_thread_, especialmente quando algoritmos recursivos são usados.

O que muitos usuários fazem, é iniciar com algum valor rasoável, e ajustar então 
se necessário.

µOS++ fornece suporte para calcular o espaço da pilha disponível para a _thread_ 
e o usuário define o mecanismos de monitoramento que invoca condições de baixo 
espaço da pilha.


``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>

using namespace os;
using namespace os::rtos;

// A thread function.
void*
th_func(void* args)
{
  // Do something.

  // Check stack.
  thread::stack& st = this_thread::thread().stack();
  std::size_t available = st.available();
  if (available < (st.size() * 20 / 100))
    {
      trace::printf("Low stack!\n");
    }

  // Do something.

  return nullptr;
}
```

Um exemplo similar, porém escrito em C:


``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>

// A thread function.
void*
th_func(void* args)
{
  // Do something.

  // Check stack.
  os_thread_stack_t* st = os_thread_get_stack(os_this_thread());
  size_t available = os_thread_stack_get_available(st);
  if (available < (os_thread_stack_get_size() * 20 / 100))
    {
      trace_printf("Low stack!\n");
    }

  // Do something.

  return NULL;
}
```

Atenção: por questões de reentrância, a facilidade `trace::printf()` requer 
algum espaço de pilha para seus buffers internos, espaço que deve ser adicionado 
para o espaço efetivo requerido pela aplicação; para o Cortex-M, aplicações 
rodando em modo de depuração, a pilha de **2000 bytes** é um bom ponto de inicio.

### Configurando o tamanho da pilha do _stack_

O tamanho do _stack_ pode ser especificado durante o tempo de criação de cada 
_thread_, usando o atributo da _thread_ `th_stack_size_bytes`. Se os atributos 
não são usados ou os valores fornecidos são zero, o valor padrão é fornecido.

Este valor padrão pode ser definido a qualuqer momento usando 
`thread::stack::default_size(std::size_t)` (em C com  
`os_thread_stack_set_default_size(size_t)`), e aplica para todas as _threads_ 
criadas depois.

O valor inicial do tamanho padrão da pilha pode ser definido durante o tempo 
de compilação com `OS_INTEGER_RTOS_DEFAULT_STACK_SIZE_BYTES`.

### O tamanho mínimo da pilha

Para questão de validação, o código da _thread_ valida o tamanho da pilha do 
_stack_ para que seja acima do valor mínimo.

Este valor pode ser definido a qualquer tempo usando 
`thread::stack::min_size(std::size_t)` (em  C com 
`os_thread_stack_set_min_size(size_t)`), e aplicar a todas as _threads_ criadas 
posteriormente.

{% comment %}by the port{% endcomment %}
Os valores iniciais do tamanho mínimo da pilha é definido pelo implementação, 
mas pode ser definida durante o tempo de compilação com 
`OS_INTEGER_RTOS_MIN_STACK_SIZE_BYTES`.

A localização recomendada para definir os valores padrões é no inicio da função 
`os_main()`:

``` c++
/// @file app-main.cpp
#include <cmsis-plus/rtos/os.h>

using namespace os;
using namespace os::rtos;

int
os_main (int argc, char* argv[])
{
  // ...

  thread::stack::min_size(1000);
  thread::stack::default_size(2500);

  // ...

  return 0;
}
```

Um exemplo similar, porém em C:

``` c
/// @file app-main.c
#include <cmsis-plus/rtos/os-c-api.h>

int
os_main (int argc, char* argv[])
{
  // ...

  os_thread_stack_set_min_size(1000);
  os_thread_stack_set_default_size(2500);

  // ...

  return 0;
}
```

### Configurando uma pilha definida para o usuário

Exceto quando usando o _template_ `thread_static`, pela _thread_ padrão são 
criadas com uma pilha alocada dinamicamente. Isso pode ser alterado pelo usuário 
definindo a pilha usando os atributos de _thread_ `th_stack_address` e `th_stack_size_bytes`.

``` c++
thread::attributtes attr;
attr.th_stack_address = th3_stack;
attr.th_stack_size_bytes = sizeof(th3_stack);

// Create a thread; the stack is statically allocated.
thread th3 { "th3", th_func, nullptr, attr };
```

Um exemplo similar, mas escrito em C:

``` c
os_thread_attr_t attr3;
os_thread_attr_init(&attr3);
attr3.th_stack_address = th3_stack;
attr3.th_stack_size_bytes = sizeof(th3_stack);

// Local storage for the thread object instance.
os_thread_t th3;

// Create a thread; the stack is statically allocated.
os_thread_create(&th3, "th3", th_func, NULL, &attr3);
```

### Detectando a sobrecarga da pilha

A detecção da sobrecarga da pilha requer suporte do hardware, que não é 
disponível nos dispositivos Cortex-M.

Apesar que isso não é infalível, já que  não evita a sobrecarga do _stack_, mas 
pode informar se está por ocorrer, é um método por software, que armazena uma 
palavra mágica no topo da pilha, e periodicamente a verifica.

µOS++ usa este método, e verifica a pilha durante a troca de contexto; uma 
assertiva `stack().check_bottom_magic()` é lançada na função  
`thread::_relink_running()` se o estouro da pilha danifica a palavra mágica

## A thread inativa (idle)

A _thread_ inativa (idle) é um componente interno do µOS++. Ela é uma _thread_ 
de baixa prioridade, sempre pronta para executar quando outras _threads_ não 
estão ativas. O código de inicialização sempre cria a _thread_ inativa, sempre 
antes do escalonador ser inicializado.

A _thread_ inativa gerencia a lista de _threads_ finalizadas e aguardando por 
serem destruídas. A chamada para `thread::exit()` liga a _thread_ sendo finalizada 
para esta lista, desde que ela não pode destruir a _thread_ enquanto ainda está 
em execução na pilha de _thread_.

Enquanto a _thread_ inativa é retomada, ela primeiro verifica esta lista e se 
alguma _thread_ está presente, ela são totalmente destruídas e possibilita que 
o espaço da pilha seja desalocado.

Quando a _thread_ inativa não tem nada para ser feito, ela coloca a CPU em modo 
_sleep_, e aguarda por uma próxima interrupção (os dispositivos Cortex-M usa a 
instrução "Aguarde por uma Interrupção" - **Wait For Interrupt - WFI** para isso).

Se necessário, o tamanho da pilha da _thread_ **inativa** pode ser configurado 
durante o tempo de compilação com `OS_INTEGER_RTOS_IDLE_STACK_SIZE_BYTES`.

## A thread principal

A _thread_ principal é um componente interno opcional para o µOS++. Se a função 
`main()` não é definida pela aplicação, uma versão padrão e vazia é provida 
pelo µOS++.

Esta função `main()`cria uma thread inicial chamada exatamente **main**, com 
prioridade normal, que é configurada para iniciar a função 
`os_main(int argc, char* argv[])` fornecida pelo usuário com sendo a função 
da _thread_

Se necessário, o tamanho da pilha da _thread_ **main** pode ser configurado 
durante o tempo de compilação com `OS_INTEGER_RTOS_MAIN_STACK_SIZE_BYTES`.
