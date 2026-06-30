import Foundation

import RxSwift

import UserAbstraction
import API
 
public struct UserService {

    private let apiProvider: APIProviderProtocol

    init(apiProvider: APIProviderProtocol = APIProvider()) {
        self.apiProvider = apiProvider
    }

    func addUser(user: UserDomainModelProtocol) -> Observable<UserDTO> {
        
        let userRequestBody = UserDTO(
            id: user.id,
            userName: user.userName
        )
        
        return apiProvider.perform(
            
            UserServiceAPI.addUser(user: userRequestBody)
        )
        .map(UserDTO.self)

    }
}

