<?php

namespace App\Security;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Lle\CredentialBundle\Entity\Group;
use Lle\OAuthClientBundle\Provider\LleResourceOwner;
use Lle\OAuthClientBundle\Service\OAuth2Service;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\AuthenticationException;
use Symfony\Component\Security\Http\Authenticator\AbstractAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\Authenticator\Passport\SelfValidatingPassport;
use Symfony\Component\Security\Http\Util\TargetPathTrait;

class OAuthAuthenticator extends AbstractAuthenticator
{
    use TargetPathTrait;

    public function __construct(
        private EntityManagerInterface $em,
        private OAuth2Service $auth2Service
    ) {
    }

    public function supports(Request $request): ?bool
    {
        return $request->attributes->get('_route') === 'login_check';
    }

    public function authenticate(Request $request): Passport
    {
        $code = $this->auth2Service->check($request);
        $resourceOwner = $this->auth2Service->fetchRessourceOwner($code);

        return new SelfValidatingPassport(
            new UserBadge($resourceOwner->getUsername(), function () use ($resourceOwner) {

                /** @var User $user */
                $user = $this->em->getRepository(User::class)
                    ->findOneBy(['connectId' => $resourceOwner->getId()]) ?? new User();

                $profil = null;
                if ($resourceOwner->toArray()['profiles']) {
                    $profil = $this->em->getRepository(Group::class)->findOneBy([
                        'name' => $resourceOwner->toArray()['profiles'][0]['name'],
                    ]);
                }

                /** @var list<string> $roles */
                $roles = $resourceOwner->getRoles();

                $user
                    ->setUsername($resourceOwner->getUsername())
                    ->setEmail($resourceOwner->getEmail())
                    ->setPrenom($resourceOwner->getPrenom())
                    ->setNom($resourceOwner->getNom())
                    ->setActif(true)
                    ->setConnectId($resourceOwner->getId())
                    ->setProfil($profil)
                    ->setRoles($roles);

                $this->em->persist($user);
                $this->em->flush();

                return $user;
            })
        );
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
    {
        $targetPath = $this->getTargetPath($request->getSession(), $firewallName);

        if (!$targetPath) {
            return new RedirectResponse('/');
        }

        return new RedirectResponse($targetPath);
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response
    {
        $data = [
            'message' => strtr($exception->getMessageKey(), $exception->getMessageData()),
        ];

        return new JsonResponse($data, Response::HTTP_FORBIDDEN);
    }
}
